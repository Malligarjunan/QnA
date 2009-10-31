# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include SuperExceptionNotifier
  include ExceptionNotifierHelper
  self.error_layout = 'error'

  include AuthenticatedSystem
  include Subdomains
  local_addresses.clear

  protect_from_forgery

  before_filter :find_conditions
  before_filter :set_locale

  protected
  def access_denied
    raise AccessDenied
  end


  def current_group
    #FIXME ensure that the current group exists
    subdomains = request.subdomains
    subdomains.delete("www")
    unless subdomains.empty?
      @current_group ||= begin
        group = Group.find(:first, :limit => 1, :conditions => {:state => "active",
                                             :subdomain => subdomains.last})
        group
      end
    end
    @current_group ||= Group.find_by_name(AppConfig.application_name)
    @current_group
  end
  helper_method :current_group

  def current_category
    params.fetch(:category, "all")
  end
  helper_method :current_category

  def find_conditions
    @languages ||= begin
      subdomains = request.subdomains
      subdomains.delete("www")
      subdomains.select{ |subdomain| AVAILABLE_LANGUAGES.include?(subdomain) }
    end
  end

  def scoped_conditions(conditions = {})
    if tags = params[:tags]
      tags = [params[:tags]] if !tags.kind_of? Array
      conditions.deep_merge!({:tags => {:$in => tags}})
    end
    conditions.deep_merge!({:group_id => current_group.id})
    conditions.deep_merge!(language_conditions)
    conditions.deep_merge!(categories_conditions)
  end
  helper_method :scoped_conditions

  def language_conditions
    conditions = {}
    if @languages && !@languages.empty?
      conditions[:language] = { :$in => @languages}
    elsif current_user && !current_user.preferred_languages.empty?
      conditions[:language] = { :$in => current_user.preferred_languages}
    elsif params[:language]
      langs = params[:language].kind_of?(Array) ? params[:language] : [params[:language]]
      conditions[:language] = {:$in => langs}
    else
      conditions[:language] = {:$in => [I18n.locale.to_s.split("-").first]}
    end
    conditions
  end
  helper_method :language_conditions

  def categories_conditions
    conditions = {}
    if current_category != "all"
      conditions.deep_merge!({:category => current_category})
    end
    conditions
  end
  helper_method :categories_conditions

  def available_locales; AVAILABLE_LOCALES; end

  def set_locale
    locale = 'en'
    if logged_in?
      locale = current_user.language
    elsif params[:lang] =~ /^(\w\w)/
      locale = find_valid_locale($1)
    else
      if request.env['HTTP_ACCEPT_LANGUAGE'] =~ /^(\w\w)/
        locale = find_valid_locale($1)
      end
    end

    I18n.locale = locale
  end

  def find_valid_locale(lang)
    case lang
      when /^es/
        'es-AR'
      when "fr"
        'fr'
      else
        'en'
    end
  end
  helper_method :find_valid_locale

  def set_page_title(title)
    @page_title = title
  end

  def page_title
    if @page_title
      "#{@page_title} - #{AppConfig.application_name}: #{t("layouts.application.title")}"
    else
      "#{AppConfig.application_name} - #{t("layouts.application.title")}"
    end
  end
  helper_method :page_title

  def add_feeds_url(url, title="atom")
    @feed_urls = [] unless @feed_urls
    @feed_urls << [title, url]
  end

  def moderator_required
    unless current_user.moderator?
      access_denied
#       flash[:error] = t("global.permission_denied")
#       redirect_to root_path
    end
  end
end
