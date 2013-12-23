module Newsletter
  class PiecesController < ApplicationController
    layout 'admin'
    before_filter :find_piece, :except => [:new,:create,:index]
    before_filter :find_newsletter
    before_filter :find_element
    before_filter :find_area

    def index
      @pieces = @newsletter.pieces.active
    end

    def show
    end

    def new
      @piece = Piece.new({
        :area_id => @area.id,
        :element_id => @element.id,
        :newsletter_id => @newsletter.id
      })
    end

    def edit
    end

    def create
      @piece = Piece.new(params[:newsletter_piece])
      if @piece.save
        flash[:notice] = 'Piece was successfully created.'
        redirect_to(edit_newsletter_path(@newsletter))
      else
        render :action => "new"
      end
    end

    def update
      if @piece.update_attributes(params[:newsletter_piece])
        flash[:notice] = 'Piece was successfully updated.'
        redirect_to(edit_newsletter_path(@newsletter))
      else
        render :action => "edit"
      end
    end

    def destroy
      @piece.destroy
      redirect_to(newsletter_path(@newsletter,:editor=>1))
    end
  
    protected 
  
    def find_piece 
      @piece = Piece.find_by_id(params[:id])
    end
  
    def find_newsletter
      return @newsletter = @piece.newsletter unless @piece.nil?
      @newsletter = ::Newsletter::Newsletter.find(params[:newsletter_id] || params[:newsletter_piece][:newsletter_id])
    end
  
    def find_element
      return @element = @piece.element unless @piece.nil?
      @element = Element.find(params[:element_id] || params[:newsletter_piece][:element_id])
    end
  
    def find_area
      return @area = @piece.area unless @piece.nil?
      @area = Area.find(params[:area_id] || params[:newsletter_piece][:area_id])
    end
  end
end
