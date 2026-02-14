module Api
  module Collections
    class PostsController < ApplicationController
      before_action :set_collection
      before_action :authenticate_user!, except: [:index, :show]
      before_action :set_post, only: [:show, :update]
      skip_before_action :verify_authenticity_token

      def index
        @posts = @collection.posts
        render json: @posts
      end

      def show
        render json: @post
      end

      def create
        authorize_resource_owner!(@collection)

        @post = @collection.posts.build(post_params)
        @post.owner = current_user

        if @post.save
          render json: @post, status: :created
        else
          render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize_resource_owner!(@post)

        if @post.update(post_params)
          render json: @post
        else
          render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_collection
        @collection = Collection.find_by(alias: params[:collection_alias])
        render json: { error: "Not found" }, status: :not_found if @collection.nil?
      end

      def set_post
        @post = @collection.posts.find_by(id: params[:id])
        render json: { error: "Not found" }, status: :not_found if @post.nil?
      end

      def post_params
        params.require(:post).permit(:title, :slug, :content, :privacy, :language, :rtl)
      end
    end
  end
end
