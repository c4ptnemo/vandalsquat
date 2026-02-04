class EntriesController < ApplicationController
  before_action :require_login
  before_action :set_entry, only: [:edit, :update, :destroy]

  def index
    @entries = current_user.entries.order(created_at: :desc)
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

# Update your EntriesController index action with this comprehensive filter logic

def index
  @entries = current_user.entries

  # Text search (searches across writer, address, notes)
  if params[:query].present?
    search_query = "%#{params[:query]}%"
    @entries = @entries.where(
      "writer_name LIKE ? OR address LIKE ? OR notes LIKE ?",
      search_query, search_query, search_query
    )
  end

  # Pin type filter (multiple selection)
  if params[:pin_types].present?
    @entries = @entries.where(pin_type: params[:pin_types])
  end

  # Writer filter
  if params[:writer].present?
    @entries = @entries.where("writer_name LIKE ?", "%#{params[:writer]}%")
  end

  # Location filter
  if params[:location].present?
    @entries = @entries.where("address LIKE ?", "%#{params[:location]}%")
  end

  # Date range filter
  if params[:date_from].present?
    @entries = @entries.where("found_on >= ?", params[:date_from])
  end

  if params[:date_to].present?
    @entries = @entries.where("found_on <= ?", params[:date_to])
  end

  # Notes filter
  if params[:notes].present?
    @entries = @entries.where("notes LIKE ?", "%#{params[:notes]}%")
  end

  # Order by most recent first
  @entries = @entries.order(found_on: :desc)
end
