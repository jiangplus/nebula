module Api
  class CollectionsController < ApplicationController
    before_action :authenticate_user!, except: [:show, :index]
    before_action :set_collection, only: [:show, :update, :destroy]
    skip_before_action :verify_authenticity_token

    def index
      @collections = Collection.where(public: true)
      render json: @collections
    end

    def show
      if can_access_collection?(@collection)
        render json: @collection
      else
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end

    def create
      @collection = current_user.collections.build(collection_params)

      if @collection.save
        render json: @collection, status: :created
      else
        render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      unless @collection.owner_id == current_user.id || current_user.is_admin?
        render json: { error: "Forbidden" }, status: :forbidden
        return
      end

      if @collection.update(collection_params)
        render json: @collection
      else
        render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_resource_owner!(@collection)

      @collection.destroy!
      render json: { message: "Collection deleted" }, status: :ok
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:alias])
      render json: { error: "Not found" }, status: :not_found if @collection.nil?
    end

    def collection_params
      permitted = params.require(:collection).permit(:alias, :title, :description, :public, :visibility)
      # Ensure visibility is valid string, or remove it to keep existing value
      if permitted[:visibility].present? && !Collection::VISIBILITY_OPTIONS.include?(permitted[:visibility])
        permitted.delete(:visibility)
      end
      permitted
    end
  end
end
