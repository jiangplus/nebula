module Collections
  class PostsController < ApplicationController
    before_action :set_collection
    before_action :set_post, only: [:show]

    def index
      if can_access_collection?(@collection)
        @posts = @collection.posts.where(privacy: 0).order(created_at: :desc)
        render :index
      else
        redirect_to root_path, alert: "Access denied"
      end
    end

    def show
      if can_access_post?(@post)
        render :show
      else
        redirect_to root_path, alert: "Access denied"
      end
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias] || params[:id])
      redirect_to root_path, alert: "Collection not found" if @collection.nil?
    end

    def set_post
      @post = @collection.posts.find_by(slug: params[:slug])
      redirect_to root_path, alert: "Post not found" if @post.nil?
    end
  end
end
