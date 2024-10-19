# Preview all emails at http://localhost:3000/rails/mailers/contact_mailer
class ContactMailerPreview < ActionMailer::Preview
  def contact_email
    # This is how you pass value to params[:user] inside mailer definition!
    contact = Contact.new(name: "Test User", email: "test@example.com", message: "This is a test message.")
    ContactMailer.contact_email(contact)
  end
end
