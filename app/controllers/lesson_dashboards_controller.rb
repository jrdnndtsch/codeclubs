class LessonDashboardsController < ApplicationController
	# respond_to :html, :js
	def index
		@lesson_bookmarked = current_user.find_up_voted_items

		@lesson_drafts = current_user.lessons.has_been_submitted?(false)
		@lesson_submitted = current_user.lessons.has_been_submitted?(true)

		if params[:draft_filters]
			if params[:lesson_title]
				@lesson_drafts = params[:lesson_title]['Lesson Title'].present? && params[:lesson_title]['Lesson Title'] == '1' ? @lesson_drafts.order('title desc') : @lesson_drafts.order('title asc')
			end
			if params[:lesson_updated]
				@lesson_drafts = params[:lesson_updated]['Updated'].present? && params[:lesson_updated]['Updated'] == '1' ? @lesson_drafts.order('updated_at desc') : @lesson_drafts.order('updated_at asc')
			end
		end

		if params[:submitted_filters]
			if params[:submitted_lesson_title]
				@lesson_submitted = params[:submitted_lesson_title]['Lesson Title'].present? && params[:submitted_lesson_title]['Lesson Title'] == '1' ? @lesson_submitted.order('title desc') : @lesson_submitted.order('title asc')
			end
			if params[:submitted_lesson_updated]
				@lesson_submitted = params[:submitted_lesson_updated]['Updated'].present? && params[:submitted_lesson_updated]['Updated'] == '1' ? @lesson_submitted.order('updated_at desc') : @lesson_submitted.order('updated_at asc')
			end
		end


		#TODO ordering with acts as taggable

		if params[:draft_filters]
			respond_to do |format|
				format.js { render :partial => "lesson_drafts_js" }
			end
		end
		if params[:submitted_filters]
			respond_to do |format|
				format.js { render :partial => "lesson_submitted_js" }
			end
		end	
 end
end