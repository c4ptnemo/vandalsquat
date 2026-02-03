class EntriesController < ApplicationController
  before_action :require_login
  before_action :set_entry, only: [:edit, :update]

  def index
    @entries = current_user.entries.order(created_at: :desc)
  end

  # Step 1: map page (no DB write)
  def new
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

  private

  def set_entry
    # Ownership enforcement: users can only edit their own entries
    @entry = current_user.entries.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:writer_name, :notes, :found_on, :latitude, :longitude, :photo)
  end
end
