# fediporter
Notes on importing content to Mastodon. Very early version. Pull requests welcome. (It's unlikely that I will work on this for long.)

Where it started: https://det.social/@luca/109559157244375603

I run a personal Mastodon instance and wanted to import my Tweets without spamming my followers, the local timeline or other instances. In this repo you will find with what I came up. It's not meant for end users but admins who are okay with losing all their data. 

# Modding Mastodon
Mastodon does not allow the import of posts/toots/statuses, but as admins of our own instance, we can adapt it to our needs. 

I decided to add an created_at parameter to the API to allow the creation of backdated posts. Two files need to be changed. My instance uses the linuxserver docker image (https://docs.linuxserver.io/images/docker-mastodon) on an Unraid server. The mod_mastodon.sh script is adapted to that setup and can be executed from the Unraid console. It changes two files: app/controllers/api/v1/statuses_controller.rb and app/services/post_status_service.rb. After changing those files, you need to restart your server. If you use a different environment, you probably need to change the paths.

app/controllers/api/v1/statuses_controller.rb
```
  def create
    @status = PostStatusService.new.call(
      current_user.account,
      text: status_params[:status],
      thread: @thread,
      media_ids: status_params[:media_ids],
      sensitive: status_params[:sensitive],
      spoiler_text: status_params[:spoiler_text],
      visibility: status_params[:visibility],
      language: status_params[:language],
      scheduled_at: status_params[:scheduled_at],
      created_at: status_params[:created_at],
      application: doorkeeper_token.application,
      poll: status_params[:poll],
      idempotency: request.headers['Idempotency-Key'],
      with_rate_limit: true
    )
```

```
  def status_params
    params.permit(
      :status,
      :in_reply_to_id,
      :sensitive,      :spoiler_text,      :visibility,
      :language,
      :scheduled_at,
      :created_at,
      media_ids: [],
      poll: [
        :multiple,
        :hide_totals,
        :expires_in,
        options: [],
      ]
    )
  end
```

To not spam anyone, posts with a created_at parameter won't be pushed. That's what the changes to post_status_service.rb prevent.

app/services/post_status_service.rb
```
def postprocess_status!
    Trends.tags.register(@status)il  LinkCrawlWorker.perform_async(@status.id)
    if not @options[:created_at]
      DistributionWorker.perform_async(@status.id)
      ActivityPub::DistributionWorker.perform_async(@status.id)
    end
    PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll
  end
```
```
def status_attributes
    {
      text: @text,
      created_at: @options[:created_at],
      media_attachments: @media || [],
      ordered_media_attachment_ids: (@options[:media_ids] || []).map(&:to_i) & @media.map(&:id),
      thread: @in_reply_to,
      poll_attributes: poll_attributes,
      sensitive: @sensitive,
      spoiler_text: @options[:spoiler_text] || '',
      visibility: @visibility,
      language: valid_locale_cascade(@options[:language], @account.user&.preferred_posting_language, I18n.default_locale),
      application: @options[:application],
      rate_limit: @options[:with_rate_limit],
    }.compact
  end
```

# Adding content through the API
Now that the API supports a created_at parameter, we can import any content through the API. I am most familiar with Python, so I went with that. The first content I tried was my Twitter archive. That's what the tweets-to-mastodon.py does (I use it in a Jupyter Notebook, but currently too lazy to clean it up, so only fragments.)

Already works:
- Replace @username with @username@twitter.com
- Upload media (can use higher resolution media from https://github.com/timhutton/twitter-archive-parser)
- Threads are recreated as threads (very fragile because post IDs are only stored in a variable)
- t.co URLs are replaced with the expanded versions

Planned:
- Retweets (currently, they are skipped because they are often truncated and that would be silly)
- Alt texts (they aren't included in the Twitter archive and we will need to retreive them from the API or website)
- Making import of replies optional
- Edited Tweets (should all versions be imported?)
