# frozen_string_literal: true

class EntriesController < ApplicationController
  before_action :require_login
  before_action :set_entry, only: [:edit, :update, :destroy]

  def index
    @entries = current_user.entries

    # Text search (searches across writer, address, notes) - case insensitive
    if params[:query].present?
      search_query = "%#{params[:query].downcase}%"
      @entries = @entries.where(
        "LOWER(writer_name) LIKE ? OR LOWER(address) LIKE ? OR LOWER(notes) LIKE ?",
        search_query, search_query, search_query
      )
    end

    # Pin type filter (multiple selection)
    if params[:pin_types].present?
      @entries = @entries.where(pin_type: params[:pin_types])
    end

    # Writer filter - case insensitive
    if params[:writer].present?
      @entries = @entries.where("LOWER(writer_name) LIKE ?", "%#{params[:writer].downcase}%")
    end

    # Location filter - case insensitive
    if params[:location].present?
      @entries = @entries.where("LOWER(address) LIKE ?", "%#{params[:location].downcase}%")
    end

    # Date range filter
    if params[:date_from].present?
      @entries = @entries.where("found_on >= ?", params[:date_from])
    end

    if params[:date_to].present?
      @entries = @entries.where("found_on <= ?", params[:date_to])
    end

    # Notes filter - case insensitive
    if params[:notes].present?
      @entries = @entries.where("LOWER(notes) LIKE ?", "%#{params[:notes].downcase}%")
    end

    # Order by most recent first (nulls last)
    @entries = @entries.order(Arel.sql("COALESCE(found_on, '1900-01-01') DESC"))
  end

  # Step 1 (map) now lives on the homepage.
  # Keep this route for compatibility, but redirect users to the map-first flow.
  def new
    redirect_to root_path
  end

  # Step 2: details form page (still no DB write)
  def details
    @entry = Entry.new(latitude: params[:lat], longitude: params[:lng])
  end

  def create
    @entry = current_user.entries.new(entry_params_without_photo)

    @entry.address = MapboxReverseGeocoder.lookup(
      @entry.latitude,
      @entry.longitude
    )

    # CRITICAL: Scrub EXIF before attaching photo
    scrubbed_file = nil
    if params.dig(:entry, :photo).present?
      begin
        scrubbed_file = ExifScrubberService.scrub(params[:entry][:photo])
        
        # Attach the file - DON'T close it yet, Active Storage needs it during save
        @entry.photo.attach(
          io: File.open(scrubbed_file.path),
          filename: params[:entry][:photo].original_filename,
          content_type: params[:entry][:photo].content_type
        )
      rescue ExifScrubberService::ExifScrubbingError => e
        scrubbed_file&.close!
        flash.now[:alert] = "Photo upload failed: #{e.message}"
        render :details, status: :unprocessable_entity
        return
      rescue => e
        scrubbed_file&.close!
        Rails.logger.error "Unexpected error during photo upload: #{e.message}"
        flash.logger.error e.backtrace.join("\n")
        flash.now[:alert] = "Photo upload failed. Please try again."
        render :details, status: :unprocessable_entity
        return
      end
    end

    # Save the entry - temp file still exists
    if @entry.save
      # NOW clean up the temp file after successful save
      scrubbed_file&.close! if scrubbed_file
      redirect_to root_path, notice: "Entry created."
    else
      # Clean up on failure
      scrubbed_file&.close! if scrubbed_file
      flash.now[:alert] = @entry.errors.full_messages.to_sentence
      render :details, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # CRITICAL: Scrub EXIF before updating photo
    scrubbed_file = nil
    if params.dig(:entry, :photo).present?
      begin
        scrubbed_file = ExifScrubberService.scrub(params[:entry][:photo])
        
        # Attach the file
        @entry.photo.attach(
          io: File.open(scrubbed_file.path),
          filename: params[:entry][:photo].original_filename,
          content_type: params[:entry][:photo].content_type
        )
      rescue ExifScrubberService::ExifScrubbingError => e
        scrubbed_file&.close!
        flash.now[:alert] = "Photo upload failed: #{e.message}"
        render :edit, status: :unprocessable_entity
        return
      rescue => e
        scrubbed_file&.close!
        Rails.logger.error "Unexpected error during photo update: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        flash.now[:alert] = "Photo upload failed. Please try again."
        render :edit, status: :unprocessable_entity
        return
      end
    end

    # Update the entry
    if @entry.update(entry_params_without_photo)
      # Clean up after successful update
      scrubbed_file&.close! if scrubbed_file
      redirect_to entries_path, notice: "Entry updated."
    else
      # Clean up on failure
      scrubbed_file&.close! if scrubbed_file
      flash.now[:alert] = @entry.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to entries_path, notice: "Entry deleted."
  end

def download_all
  require 'zip'
  require 'tempfile'
  
  @entries = current_user.entries.includes(photo_attachment: :blob)
  
  if @entries.empty?
    redirect_to entries_path, alert: "You have no entries to download."
    return
  end
  
  # Create temporary zip file
  temp_file = Tempfile.new(['vandalsquat_entries', '.zip'])
  
  begin
    Zip::File.open(temp_file.path, create: true) do |zipfile|  # CHANGED THIS LINE
      # Group entries by writer name
      entries_by_writer = @entries.group_by { |e| e.writer_name.presence || "Unknown" }
      
      entries_by_writer.each do |writer_name, entries|
        # Sanitize folder name (remove invalid characters)
        safe_writer_name = writer_name.gsub(/[^0-9A-Za-z.\-_]/, '_')
        
        entries.each_with_index do |entry, index|
          folder_prefix = "#{safe_writer_name}/"
          
          # Add photo if attached
          if entry.photo.attached?
            begin
              photo_data = entry.photo.download
              extension = File.extname(entry.photo.filename.to_s)
              photo_filename = "#{folder_prefix}#{index + 1}_photo#{extension}"
              zipfile.get_output_stream(photo_filename) { |f| f.write(photo_data) }
            rescue => e
              Rails.logger.error "Failed to download photo for entry #{entry.id}: #{e.message}"
            end
          end
          
          # Add text file with entry details
          details_txt = <<~TEXT
            VandalSquat Entry
            
            Writer: #{entry.writer_name}
            Date Found: #{entry.found_on}
            Location: #{entry.latitude}, #{entry.longitude}
            Pin Type: #{entry.pin_type}
            Notes: #{entry.notes}
            
            Created: #{entry.created_at}
            Entry ID: #{entry.id}
          TEXT
          
          txt_filename = "#{folder_prefix}#{index + 1}_details.txt"
          zipfile.get_output_stream(txt_filename) { |f| f.write(details_txt) }
          
          # Add JSON file with entry details
          details_json = {
            id: entry.id,
            writer_name: entry.writer_name,
            found_on: entry.found_on,
            latitude: entry.latitude,
            longitude: entry.longitude,
            pin_type: entry.pin_type,
            notes: entry.notes,
            created_at: entry.created_at,
            updated_at: entry.updated_at,
            photo_url: entry.photo.attached? ? url_for(entry.photo) : nil
          }.to_json
          
          json_filename = "#{folder_prefix}#{index + 1}_details.json"
          zipfile.get_output_stream(json_filename) { |f| f.write(details_json) }
        end
      end
      
      # Add overall summary file
      summary = "VandalSquat Export\n"
      summary += "=" * 50 + "\n\n"
      summary += "User: #{current_user.username}\n"
      summary += "Total Entries: #{@entries.count}\n"
      summary += "Export Date: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
      summary += "Writers: #{entries_by_writer.keys.join(', ')}\n\n"
      summary += "=" * 50 + "\n\n"
      
      entries_by_writer.each do |writer, entries|
        summary += "#{writer} (#{entries.count} entries)\n"
        entries.each_with_index do |entry, i|
          summary += "  #{i + 1}. #{entry.found_on} - #{entry.pin_type}\n"
        end
        summary += "\n"
      end
      
      zipfile.get_output_stream("_README.txt") { |f| f.write(summary) }
      
      # Add master JSON with all entries
      all_entries_json = @entries.map do |entry|
        {
          id: entry.id,
          writer_name: entry.writer_name,
          found_on: entry.found_on,
          latitude: entry.latitude,
          longitude: entry.longitude,
          pin_type: entry.pin_type,
          notes: entry.notes,
          created_at: entry.created_at,
          photo_url: entry.photo.attached? ? url_for(entry.photo) : nil
        }
      end.to_json
      
      zipfile.get_output_stream("all_entries.json") { |f| f.write(all_entries_json) }
    end
    
    # Send file to user
    send_file temp_file.path, 
              filename: "vandalsquat_#{current_user.username}_#{Date.today}.zip",
              type: 'application/zip',
              disposition: 'attachment'
  ensure
    temp_file.close
    temp_file.unlink
  end
end

  private

  def set_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:writer_name, :notes, :found_on, :latitude, :longitude, :photo, :pin_type)
  end

  # Same as entry_params but without :photo (handled separately to scrub EXIF)
  def entry_params_without_photo
    params.require(:entry).permit(:writer_name, :notes, :found_on, :latitude, :longitude, :pin_type)
  end
end

