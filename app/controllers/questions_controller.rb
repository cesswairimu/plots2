class QuestionsController < ApplicationController
  private

  def filter_questions_by_tag(questions, tagnames)
    tagnames ||= ''
    tagnames = tagnames.split(',')
    nids = questions.collect(&:nid)
    questions = Node.where(status: 1, type: 'note')
      .joins(:tag)
      .where('node.nid IN (?)', nids)
      .group('node.nid')
    if !tagnames.empty?
      questions.where('term_data.name IN (?)', tagnames)
    else
      questions
    end
  end

  public

  def index
    params[:period]
    @asked = Node.questions.to_a.size
    @answered = Answer.all.map(&:node).uniq.size
    @title = 'Questions and Answers'

    set_sidebar
    @questions = Node.questions
      .where(status: 1)
      .order('node.nid DESC')
      .paginate(page: params[:page], per_page: 24)
    @week_asked = Node.questions.where('created >= ?', 1.week.ago.to_i).to_a.size
    @month_asked = Node.questions.where('created >= ?', 1.month.ago.to_i).to_a.size
    @year_asked = Node.questions.where('created >= ?', 1.year.ago.to_i).to_a.size
    @week_answered = Answer.where("created_at >= ?", 1.week.ago).map(&:node).uniq.size
    @month_answered = Answer.where("created_at >= ?", 1.month.ago).map(&:node).uniq.size
    @year_answered = Answer.where("created_at >= ?", 1.year.ago).map(&:node).uniq.size
    @period = [@week_asked, @month_asked, @year_asked]
  end

  # a form for new questions, at /questions/new
  def new
    # use another node body as a template
    node_id = params[:n].to_i
    if node_id && !params[:body] && Node.exists?(node_id)
      node = Node.find(node_id)
      params[:body] = node.body
    end
    if current_user.nil?
      redirect_to new_user_session_path(return_to: request.path)
      flash[:notice] = "Your question is important and we want to hear from you! Please log in or sign up to post a question"
    else
      if params[:legacy]
        render 'editor/question'
      else
        render 'editor/questionRich'
      end
    end
  end

  def show
    if params[:author] && params[:date]
      @node = Node.find_notes(params[:author], params[:date], params[:id])
      @node ||= Node.where(path: "/report/#{params[:id]}").first
    else
      @node = Node.find params[:id]
    end

    redirect_to @node.path unless @node.has_power_tag('question')

    alert_and_redirect_moderated

    impressionist(@node)
    @title = @node.latest.title
    @tags = @node.power_tag_objects('question')
    @tagnames = @tags.collect(&:name)
    @users = @node.answers.group(:uid)
      .order(Arel.sql('count(*) DESC'))
      .collect(&:author)

    # Arel.sql is used to remove a Deprecation warning while updating to rails 5.2

    set_sidebar :tags, @tagnames
  end

  def answered
    @title = 'Recently answered'
    @questions = Node.questions
      .where(status: 1)
    @questions = filter_questions_by_tag(@questions, params[:tagnames])
      .joins(:answers)
      .order('answers.created_at DESC')
      .group('node.nid')
      .paginate(page: params[:page], per_page: 24)
    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')
    render template: 'questions/index'
  end

  def unanswered
    @title = 'Unanswered questions'
    @questions = Node.questions
      .where(status: 1)
      .includes(:answers)
      .references(:answers)
      .where(answers: { id: nil })
      .order('node.nid DESC')
      .group('node.nid')
      .paginate(page: params[:page], per_page: 24)
    render template: 'questions/index'
  end

  def shortlink
    @node = Node.find params[:id]
    if @node.has_power_tag('question')
      redirect_to @node.path(:question)
    else
      redirect_to @node.path
    end
  end

  def popular
    @title = 'Popular Questions'
    @questions = Node.questions
      .where(status: 1)
    @questions = filter_questions_by_tag(@questions, params[:tagnames])
      .order('views DESC')
      .limit(20)

    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')
    @unpaginated = true
    render template: 'questions/index'
  end

  def liked
    @title = 'Highly liked Questions'
    @questions = Node.questions.where(status: 1)
    @questions = filter_questions_by_tag(@questions, params[:tagnames])
      .order('cached_likes DESC')
      .limit(20)

    @wikis = Node.limit(10)
      .where(type: 'page', status: 1)
      .order('nid DESC')
    @unpaginated = true
    render template: 'questions/index'
  end
end
