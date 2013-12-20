=begin rdoc
Author::    Chris Hauboldt (mailto:biz@lnstar.com)
Copyright:: 2009 Lone Star Internet Inc.

Newsletter ties user-added data to a Newsletter::Design through Newsletter::Pieces. 

Newsletter also registers itself to be Mailable through the List Manager of Mailing if the plugin exists. (MLM isn't a nice term apparently) It is also the starting point for rendering a newsletter for both the web archive and when being sent as a mailable. A newsletter will show up on an archives page and be available to send in an email after it is "Published". Newsletters may also be Un-Published.

=end

require 'net/http'
require 'will_paginate'
module Newsletter
  class Newsletter < ActiveRecord::Base
    self.table_name =  "#{Conf.newsletter_table_prefix}newsletters"
    belongs_to :design, :class_name => 'Newsletter::Design'
    has_many :pieces, :order => 'sequence', :class_name => 'Newsletter::Piece', 
      :conditions => "#{Conf.newsletter_table_prefix}pieces.deleted_at is null"
  
    scope :published, {:conditions => "#{Conf.newsletter_table_prefix}newsletters.published_at is not null", 
      :order => "#{Conf.newsletter_table_prefix}newsletters.created_at desc"}
    scope :active, {:conditions => "#{Conf.newsletter_table_prefix}newsletters.deleted_at is null", 
      :order => "#{Conf.newsletter_table_prefix}newsletters.created_at desc"}
  
    validates_presence_of :name
  
    acts_as_list :column => :sequence

    attr_protected :id

    def headlines
      pieces.select{|piece| piece.respond_to?(:headline)}
    end

    # returns the newsletter's content as plain text
    def email_text
      "Get the new Newsletter from here: " + public_url + "\n" +
      '-'*30 + "\n\n" + generate_plain_text('email')
    end

    # returns the newsletter's content as html text with unsubscribe data(this should be encapsulated in an 
    #   "if is_email" block in your design)
    def email_html
      generate('email')
    end
  
    # Currently using lynx to generate newsletter as text
    def generate_plain_text(mode='')
      IO.popen('lynx -stdin --dump','w+') do |lynx|
        lynx.write generate(mode)
        lynx.close_write
        lynx.readlines.join
      end
    end

    def published?
      !published_at.nil?
    end

    # sets published_at to current time, so it will be shown in the archives page
    def publish
      update_attribute(:published_at, Time.now)
    end
  
    # clears published_at so that it is removed from the archives page
    def unpublish
      update_attribute(:published_at, nil)
    end

    # generates a public url for the newsletter
    def public_url(mode='')
      "#{Conf.site_url}/newsletters/#{self[:id]}#{mode.blank? ? '' : "/#{mode}"}"
    end
  
    # used to generate the newsletter from a model or someplace other than the web stack
    #   FIXME: There has to be a better way, where railsy stuff works ... erb doesn't seem 
    #          to be enough, so we're just using the web app
    # Parameters:
    #   mode: if set to 'email', is_email? will be true as a helper in the designs, for 
    #         useage to not include javascript, show/hide subscription links, etc.
    #   substitutions: data to substitute out of the content such as "UNSUBSCRIBE_URL"
    def generate(mode='')
      fetch(public_url(mode))
    end

    # retrieve a newsletter area by name
    def area(name)
      design.areas.by_name(name).first
    end
  
    # retrieve a list of locals to send to the main layout of the newsletter design view
    # this is so that we can just "<%= area %>" without putting anything fancy in the view
    def locals
      variables = Hash.new
      design.areas.each do |area|
        variables[area.name.to_sym] = area
      end
      variables
    end
  
    def piece_attributes=(piece_attributes)
      piece_attributes.each do |attributes|
        pieces.build(attributes)
      end
    end
  
    def areas
      design.try(:areas).to_a
    end
  
    def fetch(uri_str, limit = 10)
      # You should choose better exception.
      Rails.logger.debug "Fetching #{uri_str}"
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      response = Net::HTTP.get_response(URI.parse(uri_str))
      case response
      when Net::HTTPSuccess     then response.body
      when Net::HTTPRedirection then fetch(response['location'], limit - 1)
      else
        response.error!
      end
    end
  
    if defined? MailManager::MailableRegistry.respond_to?(:object_id)
      include MailManager::MailableRegistry::Mailable
      has_many :mailings, :as => :mailable, :class_name => "MailManager::Mailing"
    end
  end
end
