module Api
  class PostsController < ApplicationController
    before_action :authenticate_user!, except: [:show]
    before_action :set_post, only: [:show, :update, :destroy]
    skip_before_action :verify_authenticity_token

    def show
      if can_access_post?(@post)
        render json: @post
      else
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end

    def create
      @post = current_user.posts.build(post_params)

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

    def destroy
      authorize_resource_owner!(@post)

      @post.destroy!
      render json: { message: "Post deleted" }, status: :ok
    end

    private

    def set_post
      @post = Post.find_by(id: params[:id])
      render json: { error: "Not found" }, status: :not_found if @post.nil?
    end

    def post_params
      params.require(:post).permit(:title, :slug, :content, :privacy, :collection_id, :language, :rtl)
    end
  end
end
