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
    @entry = current_user.entries.new(entry_params)

    @entry.address = MapboxReverseGeocoder.lookup(
      @entry.latitude,
      @entry.longitude
    )

    if @entry.save
      redirect_to root_path, notice: "Entry created."
    else
      flash.now[:alert] = @entry.errors.full_messages.to_sentence
      render :details, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @entry.update(entry_params)
      redirect_to entries_path, notice: "Entry updated."
    else
      flash.now[:alert] = @entry.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to entries_path, notice: "Entry deleted."
  end

  private

  def set_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:writer_name, :notes, :found_on, :latitude, :longitude, :photo, :pin_type)
  end
end