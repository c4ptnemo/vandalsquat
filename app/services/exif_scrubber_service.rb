# frozen_string_literal: true

# EXIF Scrubber Service for Rails
# Place this file in: app/services/exif_scrubber_service.rb
#
# This service removes all EXIF metadata from images before upload.
# It integrates seamlessly with Active Storage and Cloudinary.
#
# Usage:
#   ExifScrubberService.scrub(uploaded_file)
#
# Requirements:
#   gem 'mini_magick'  # Add to Gemfile

require 'mini_magick'

class ExifScrubberService
  class ExifScrubbingError < StandardError; end

  # Scrub EXIF data from an uploaded file
  #
  # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded file from params
  # @return [Tempfile] A temporary file with EXIF data removed
  #
  # @example
  #   scrubbed_file = ExifScrubberService.scrub(params[:photo])
  #   @entry.photo.attach(io: scrubbed_file, filename: params[:photo].original_filename)
  #
  def self.scrub(uploaded_file)
    return nil if uploaded_file.blank?

    new(uploaded_file).scrub
  end

  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
    @original_filename = uploaded_file.original_filename
  end

  def scrub
    validate_image!
    
    # Create temporary file for scrubbed image
    temp_file = create_temp_file
    
    begin
      # Process image and remove EXIF
      image = MiniMagick::Image.read(@uploaded_file.read)
      
      # Strip all metadata
      image.strip
      
      # Save to temporary file with high quality
      image.quality(95)
      image.write(temp_file.path)
      
      Rails.logger.info "EXIF scrubbed from: #{@original_filename}"
      
      temp_file
    rescue => e
      temp_file.close! if temp_file
      Rails.logger.error "EXIF scrubbing failed for #{@original_filename}: #{e.message}"
      raise ExifScrubbingError, "Failed to scrub EXIF data: #{e.message}"
    end
  end

  private

  def validate_image!
    unless @uploaded_file.content_type&.start_with?('image/')
      raise ExifScrubbingError, "File must be an image"
    end
  end

  def create_temp_file
    extension = File.extname(@original_filename)
    Tempfile.new(['scrubbed', extension]).tap do |file|
      file.binmode
    end
  end
end
