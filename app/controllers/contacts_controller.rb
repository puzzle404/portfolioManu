class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)
    if @contact.valid?
      mail = ContactMailer.with(contact: @contact).contact_email
      mail.deliver_now
      flash[:notice] = "Your message has been sent successfully!"
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :message)
  end
end
