class LessonsController < ApplicationController
  before_action :set_lesson, only: [:show, :edit, :update, :destroy, :upvote, :downvote]

  before_action :require_permission, only: [:edit, :update, :destroy]

  before_filter :authenticate_has_profile
  skip_before_action :authenticate_user!, only: [:index, :show]


  autocomplete :subject, :name, :class_name => 'ActsAsTaggableOn::Tag'
  autocomplete :code_concept, :name, :class_name => 'ActsAsTaggableOn::Tag'
  autocomplete :grade, :name, :class_name => 'ActsAsTaggableOn::Tag'

  def upvote
    @lesson.upvote_by current_user
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { render json: { count: @lesson.get_upvotes.size } }
    end
  end

  def downvote
    @lesson.downvote_by current_user
    @lesson_bookmarked = current_user.find_up_voted_items
    if params[:source] == 'lesson_dashboard'
      respond_to do |format|
        format.js { render :partial => "lesson_dashboards/lesson_bookmarked_js" }
      end
    else
      respond_to do |format|
        format.html { redirect_to :back }
        format.json { render json: { count: @lesson.get_upvotes.size } }
      end
    end
  end

  # GET /lessons
  # GET /lessons.json
  def index
    lang = session[:locale]
    @lessons = Lesson.is_approved.includes(:profile).by_language(lang).order(:cached_votes_up => :desc).first(21)
    @lessons_for_tags = Lesson.by_language(lang)
    @subject_tags = Lesson.all_tags_for_type(@lessons_for_tags, "subject")
    @concept_tags = Lesson.all_tags_for_type(@lessons_for_tags, "code_concept")
    @grade =  params[:grade] != ''? params[:grade] : 'all grades'
    @subject = params[:subject] != ''? params[:subject] : 'all subjects'
    @code_concept = params[:code_concept] != ''? params[:code_concept] : 'all coding concepts'
    @province = params[:province] != ''? params[:province] : 'all provinces'


    if params[:search_complete]
      tags = []
      # make sure to not search against blank fields
      if params[:subject] != ''
        tags.push(params[:subject])
      end
      if params[:code_concept] != ''
        tags.push(params[:code_concept])
      end
      # if params[:grade] != ''
      #   tags.push(params[:grade])
      # end
      @tags = tags
      if @tags.length > 0 && params[:verified].present?
        @lessons = Lesson.by_language(lang).is_approved.is_verified?.tagged_with(@tags).order(:cached_votes_up => :desc)
      elsif @tags.length > 0
        @lessons = Lesson.by_language(lang).is_approved.tagged_with(@tags).order(:cached_votes_up => :desc)
      elsif params[:verified].present?
        @lessons = Lesson.by_language(lang).is_approved.is_verified?.order(:cached_votes_up => :desc)
      else  
        @lessons = @lessons
      end

      if params[:province] != ''
        if params[:province] == "All" || params[:province] ==  "Tous"
          @lessons = @lessons
        else
        @lessons = @lessons.select {|lesson| lesson.province == params[:province]}
        end
      end   

      if params[:grade] != ''
        if params[:grade] == "All Grades" || params[:grade] ==  "Tous"
          @lessons = @lessons
        else
          @lessons = @lessons.select {|lesson| lesson.grade == params[:grade]}
        end
      end

      if params[:browse].present? && params[:browse] == 'list'  
        respond_to do |format|
          format.js { render :partial => "lessons_list_js", locals: {grade: @grade} }
        end
      else 
        respond_to do |format|
         format.js { render :partial => "lessons_js", locals: {grade: @grade} }
        end 
      end

    end
  end

  # GET /lessons/1
  # GET /lessons/1.json
  def show
  end

  # GET /lessons/new
  def new
    @lesson = Lesson.new
    @lesson.lesson_references.new
  end

  # GET /lessons/1/edit
  def edit
    if params[:submitted]
      @lesson.update(submitted: true)
      respond_to do |format|
        format.js {render :partial => "lesson_submitted_js"}
      end  
    end 
  end

  # POST /lessons
  # POST /lessons.json
  def create
    @lesson = Lesson.new(lesson_params)
    @lesson.profile = current_user.profile
    @lesson.subject_list.add(params[:lesson][:subject_list], parse: true)
    @lesson.code_concept_list.add(params[:lesson][:code_concept_list], parse: true)
    # @lesson.grade_list.add(params[:grade_list], parse: true) 
    @lesson.level = params[:lesson][:level].to_i
    @suggested_lessons = params[:lesson][:suggested_lessons]
    respond_to do |format|
      if @lesson.save
        if @suggested_lessons.present?
          @suggested_lessons.each do |sug_lesson|
            SuggestedLesson.create(lesson_id: @lesson.id, suggested_lesson_id: sug_lesson.to_i)
          end
        end
        format.html { redirect_to @lesson, notice: 'Lesson was successfully created.' }
        format.json { render :show, status: :created, location: @lesson }
      else
        format.html { render :new }
        format.json { render json: @lesson.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lessons/1
  # PATCH/PUT /lessons/1.json
  def update
    @lesson.subject_list.add(params[:lesson][:subject_list], parse: true)
    @lesson.code_concept_list.add(params[:lesson][:code_concept_list], parse: true)
    @suggested_lessons = params[:lesson][:suggested_lessons]
    if @suggested_lessons.present?
      @suggested_lessons.each do |sug_lesson|
        SuggestedLesson.create(lesson_id: @lesson.id, suggested_lesson_id: sug_lesson.to_i)
      end
    end
    # raise 'hell'
    respond_to do |format|
      if @lesson.update(lesson_params)
        format.html { redirect_to @lesson, notice: 'Lesson was successfully updated.' }
        format.json { render :show, status: :ok, location: @lesson }
      else
        format.html { render :edit }
        format.json { render json: @lesson.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lessons/1
  # DELETE /lessons/1.json
  def destroy
    @lesson.destroy
    respond_to do |format|
      format.html { redirect_to admin_path(:anchor => 'tab=lessons') , notice: 'Lesson was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lesson
      @lesson = Lesson.friendly.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to(root_url, :notice => 'Record not found')
    end

    def require_permission
      if current_user == Lesson.friendly.find(params[:id]).profile.user || current_user.admin?
      else
        redirect_to root_path
      end
      rescue ActiveRecord::RecordNotFound
          redirect_to(root_url, :notice => 'Record not found')
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def lesson_params
      params.require(:lesson).permit(:title, :duration_in_minutes, :level, :description, :curriculum_concepts, :prep, :programming_concepts, :content, :extensions, :answers, :video_link, :profile_id, :feature_image, :file_upload, :code_concept_list, :subject_list, :grade_list, :bootsy_image_gallery_id, :approved, :references, :submitted, :grade, :custom_color, :verification_message, :verified, :province, :language, lesson_references_attributes: [:id, :title, :url, :_destroy])
    end
end
