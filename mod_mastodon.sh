# Be careful. This only works with the linuxserver docker image on Unraid.
# It changes Mastodon files and those changes will be gone with the next update of the container.
# It should not be run multiple times because it does not test if it was run before and is stupid and destructive.
# DON'T USE IF YOU DON'T KNOW HOW TO FIX THE FILES IT CHANGES

# app/controllers/api/v1/statuses_controller.rb
# allow created_at parameter in API calls
docker exec mastodon sed -i 's/scheduled_at: status_params\[:scheduled_at\],/scheduled_at: status_params\[:scheduled_at\],\n      created_at: status_params\[:created_at\],/g' /app/www/app/controllers/api/v1/statuses_controller.rb
docker exec mastodon sed -i 's/:scheduled_at,/:scheduled_at,\n      :created_at,/g' /app/www/app/controllers/api/v1/statuses_controller.rb


# app/services/post_status_service.rb
# Stop new posts from being pushed to other servers.
docker exec mastodon sed -i 's/    DistributionWorker.perform_async(@status.id)/    if not @options[:created_at]\n      DistributionWorker.perform_async(@status.id)/g' /app/www/app/services/post_status_service.rb
docker exec mastodon sed -i 's/ActivityPub::DistributionWorker.perform_async(@status.id)/  ActivityPub::DistributionWorker.perform_async(@status.id)\n    end/g' /app/www/app/services/post_status_service.rb

# add created_at to database
docker exec mastodon sed -i 's/text: @text,/text: @text,\n      created_at: @options\[:created_at\],/g' /app/www/app/services/post_status_service.rb
