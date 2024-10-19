class ContactMailer < ApplicationMailer
  default to: 'cmanuferrer@gmail.com' # Cambia esto por tu dirección de correo electrónico

  def contact_email
    @contact = params[:contact]
    mail(from: @contact.email, subject: 'New Contact Message')
  end
end
