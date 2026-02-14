class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:create, :update, :destroy], if: -> { request.format.json? }

  # GET /me/posts
  # GET /posts
  def index
    @posts = current_user.posts
    render :index
  end

  # GET /new
  # GET /posts/new
  def new
    @post = current_user.posts.build
    render :new
  end

  # GET /d/:id
  # GET /posts/:id
  def show
    if can_access_post?(@post)
      respond_to do |format|
        format.html { render :show }
        format.json { render json: @post }
      end
    else
      redirect_to root_path, alert: "Access denied"
    end
  end

  # GET /d/:id/edit
  # GET /posts/:id/edit
  def edit
    authorize_resource_owner!(@post)
    render :edit
  end

  # POST /api/posts
  def create
    @post = current_user.posts.build(post_params)

    if @post.save
      respond_to do |format|
        format.json do
          render json: @post, status: :created
        end

        format.html do
          redirect_to draft_post_path(@post), notice: "Post created successfully"
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
        end

        format.html do
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH /api/posts/:id
  def update
    authorize_resource_owner!(@post)

    if @post.update(post_params)
      respond_to do |format|
        format.json do
          render json: @post
        end

        format.html do
          redirect_to draft_post_path(@post), notice: "Post updated successfully"
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
        end

        format.html do
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /api/posts/:id
  def destroy
    authorize_resource_owner!(@post)

    @post.destroy!

    respond_to do |format|
      format.json do
        render json: { message: "Post deleted" }, status: :ok
      end

      format.html do
        redirect_to me_posts_path, notice: "Post deleted successfully"
      end
    end
  end

  private

  def set_post
    @post = Post.find_by(id: params[:id])
    redirect_to root_path, alert: "Post not found" if @post.nil?
  end

  def post_params
    params.require(:post).permit(:title, :slug, :content, :privacy, :collection_id, :language, :rtl)
  end
end
