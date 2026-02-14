class HomeController < ApplicationController
  POSTS_PER_PAGE = 16
  MAX_POSTS_PER_AUTHOR = 5

  def index
    @page = [params[:page].to_i, 1].max

    # Public posts from public collections (visibility = 'public'), newest first
    base_scope = Post
      .joins(:collection)
      .where(collections: { visibility: "public" })
      .where("posts.privacy = 0")
      .order(created_at: :desc)

    # Limit to max 5 posts per author using a window function
    limited_posts = Post.from(
      base_scope.select("posts.*, ROW_NUMBER() OVER (PARTITION BY posts.owner_id ORDER BY posts.created_at DESC) as author_rank")
    ).where("author_rank <= ?", MAX_POSTS_PER_AUTHOR)

    @total_count = limited_posts.count
    @total_pages = (@total_count.to_f / POSTS_PER_PAGE).ceil
    @total_pages = 1 if @total_pages < 1

    @posts = limited_posts
      .offset((@page - 1) * POSTS_PER_PAGE)
      .limit(POSTS_PER_PAGE)
      .includes(:collection)
  end
end
