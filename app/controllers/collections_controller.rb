class CollectionsController < ApplicationController
  before_action :authenticate_user!, except: [:show, :index]
  before_action :set_collection, only: [:show, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:create, :update, :destroy], if: -> { request.format.json? }

  # GET /api/collections
  # GET /collections
  def index
    respond_to do |format|
      format.json do
        @collections = Collection.all
        render json: @collections
      end

      format.html do
        @collections = current_user&.collections || []
        render :index
      end
    end
  end

  # GET /api/collections/:alias
  # GET /collections/:alias
  def show
    respond_to do |format|
      format.json do
        render json: @collection
      end

      format.html do
        if can_access_collection?(@collection)
          render :show
        else
          redirect_to root_path, alert: "Access denied"
        end
      end
    end
  end

  # POST /api/collections
  def create
    @collection = current_user.collections.build(collection_params)

    if @collection.save
      respond_to do |format|
        format.json do
          render json: @collection, status: :created
        end

        format.html do
          redirect_to @collection, notice: "Collection created successfully"
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
        end

        format.html do
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH /api/collections/:alias
  def update
    authorize_resource_owner!(@collection)

    if @collection.update(collection_params)
      respond_to do |format|
        format.json do
          render json: @collection
        end

        format.html do
          redirect_to @collection, notice: "Collection updated successfully"
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
        end

        format.html do
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /api/collections/:alias
  def destroy
    authorize_resource_owner!(@collection)

    @collection.destroy!

    respond_to do |format|
      format.json do
        render json: { message: "Collection deleted" }, status: :ok
      end

      format.html do
        redirect_to user_account_path, notice: "Collection deleted successfully"
      end
    end
  end

  private

  def set_collection
    identifier = params[:alias] || params[:id]
    @collection = Collection.find_by(alias: identifier) || Collection.find_by(id: identifier)
    redirect_to root_path, alert: "Collection not found" if @collection.nil?
  end

  def collection_params
    params.require(:collection).permit(:alias, :title, :description, :public, :visibility)
  end
end
