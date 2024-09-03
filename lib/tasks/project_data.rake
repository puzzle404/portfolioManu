
desc 'Fills database with data and calculate embeddings for each item.'
task project_data: :environment do
  projects = Project.all
  openai_client = OpenAI::Client.new
  projects.each do |item|
    item.chunk!
    puts "Data for #{item.name} created!"
  end
end
