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
  @entries = current_user.entries.includes(photo_attachment: :blob)
  
  if @entries.empty?
    redirect_to entries_path, alert: "You have no entries to download."
    return
  end
  
  # Group entries by writer name
  entries_by_writer = @entries.group_by { |e| e.writer_name.presence || "Unknown" }
  
  # Create CSV export
  csv_data = CSV.generate do |csv|
    csv << ["Entry ID", "Writer", "Date Found", "Latitude", "Longitude", "Address", "Pin Type", "Notes", "Photo URL", "Created At"]
    
    @entries.each do |entry|
      csv << [
        entry.id,
        entry.writer_name,
        entry.found_on,
        entry.latitude,
        entry.longitude,
        entry.address,
        entry.pin_type,
        entry.notes,
        entry.photo.attached? ? url_for(entry.photo) : "No photo",
        entry.created_at
      ]
    end
  end
  
  # Create JSON export
  json_data = {
    export_date: Time.current,
    username: current_user.username,
    total_entries: @entries.count,
    writers: entries_by_writer.keys,
    entries: @entries.map do |entry|
      {
        id: entry.id,
        writer_name: entry.writer_name,
        found_on: entry.found_on,
        latitude: entry.latitude,
        longitude: entry.longitude,
        address: entry.address,
        pin_type: entry.pin_type,
        notes: entry.notes,
        photo_url: entry.photo.attached? ? url_for(entry.photo) : nil,
        created_at: entry.created_at,
        updated_at: entry.updated_at
      }
    end
  }.to_json(pretty: true)
  
  # Create README
  readme = <<~TEXT
    VandalSquat Data Export
    ==================================================
    
    Username: #{current_user.username}
    Export Date: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
    Total Entries: #{@entries.count}
    
    Files Included:
    - entries.csv: Spreadsheet format (open in Excel/Google Sheets)
    - entries.json: Machine-readable format
    - README.txt: This file
    
    Photos are NOT included in this export to keep download fast.
    Photo URLs are included in both CSV and JSON files.
    You can download photos by visiting the URLs or viewing them on vandalsquat.org
    
    ==================================================
    
    Entries by Writer:
    #{entries_by_writer.map { |writer, entries| "  #{writer}: #{entries.count} entries" }.join("\n")}
    
    ==================================================
  TEXT
  
  # Create zip with metadata only
  require 'zip'
  require 'tempfile'
  require 'csv'
  
  temp_file = Tempfile.new(['vandalsquat_export', '.zip'])
  
  begin
    Zip::File.open(temp_file.path, create: true) do |zipfile|
      zipfile.get_output_stream("README.txt") { |f| f.write(readme) }
      zipfile.get_output_stream("entries.csv") { |f| f.write(csv_data) }
      zipfile.get_output_stream("entries.json") { |f| f.write(json_data) }
    end
    
    send_file temp_file.path,
              filename: "vandalsquat_#{current_user.username}_#{Date.today}.zip",
              type: 'application/zip',
              disposition: 'attachment'
  ensure
    temp_file.close
    temp_file.unlink
  end
end