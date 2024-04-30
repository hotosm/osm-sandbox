#!/bin/bash

# First start web server & run migrations
bundle exec rails s -d -p 3000 -b '0.0.0.0'
bundle exec rails db:migrate

# Ruby script to create admin (to file)
# NOTE ID_EDITOR_REDIRECT_URI env var is injected
cat << EOF > create_admin_user.rb
admin_user = User.find_by(email: "#{ENV['ADMIN_EMAIL']}")
unless admin_user
  pass_crypt, pass_salt = PasswordHash.create("#{ENV['ADMIN_PASS']}")
  admin_user = User.create!(
      display_name: "HOTOSM",
      email: "#{ENV['ADMIN_EMAIL']}",
      pass_crypt: pass_crypt,
      pass_salt: pass_salt,
      email_valid: true,
      data_public: true,
      terms_seen: true,
      terms_agreed: Time.now,
      tou_agreed: Time.now,
  )
  admin_user.confirm!
  admin_user.roles.create(role: "administrator", granter_id: admin_user.id)
  admin_user.roles.create(role: "moderator", granter_id: admin_user.id)
end

oauth_application = Oauth2Application.find_by(name: 'ID Dev')
unless oauth_application
  oauth_application = Oauth2Application.create!(
      owner: admin_user,
      name: 'ID Dev',
      redirect_uri: "#{ENV['ID_EDITOR_REDIRECT_URI']}",
      scopes: ['read_prefs', 'write_api'],
      confidential: false,
  )
end
puts oauth_application.uid
puts oauth_application.secret

oauth_token = Doorkeeper::AccessToken.find_by(application_id: oauth_application.id)
unless oauth_token
  oauth_token = Doorkeeper::AccessToken.create!(
    resource_owner_id: admin_user.id,
    application_id: oauth_application.id,
    expires_in: 315360000,  # 10yrs
    scopes: 'read_prefs write_api'
  )
end
puts oauth_token.token
EOF

# Add output from Rails script to file, then extract OAuth app creds
if [ ! -e /tmp/create_admin_user.log ]; then
  bundle exec rails runner create_admin_user.rb > /tmp/create_admin_user.log
  ID_EDITOR_CLIENT_ID=$(sed -n '1p' /tmp/create_admin_user.log)
  ID_EDITOR_CLIENT_SECRET=$(sed -n '2p' /tmp/create_admin_user.log)
  ADMIN_OAUTH_TOKEN=$(sed -n '3p' /tmp/create_admin_user.log)
fi

# Stop web server gracefully
kill -TERM $(cat /tmp/pids/server.pid)

# Update the OpenStreetMap settings
# Further overrides can be made in a mounted settings.local.yml file
# The oauth_application var is for OSM Notes / changeset comments
# The id_application var is for ID editor
if ! grep -q "id_application: \"${ID_EDITOR_CLIENT_ID}\"" /app/config/settings.yml; then
  sed -i "s/#id_application: \"\"/id_application: \"${ID_EDITOR_CLIENT_ID}\"/" /app/config/settings.yml
fi

if ! grep -q "server_protocol: \"${PROTOCOL}\"" /app/config/settings.yml; then
  sed -i "s/server_protocol: \"http\"/server_protocol: \"${PROTOCOL}\"/" /app/config/settings.yml
fi

if ! grep -q "server_url: \"${DOMAIN}\"" /app/config/settings.yml; then
  sed -i "s/server_url: \"openstreetmap.example.com\"/server_url: \"${DOMAIN}\"/" /app/config/settings.yml
fi

# SMTP settings
if ! grep -q "smtp_address: \"mail\"" /app/config/settings.yml; then
  sed -i "s/smtp_address: \"localhost\"/smtp_address: \"mail\"/" /app/config/settings.yml
fi

if ! grep -q "smtp_domain: \"${DOMAIN}\"" /app/config/settings.yml; then
  sed -i "s/smtp_domain: \"localhost\"/smtp_domain: \"${DOMAIN}\"/" /app/config/settings.yml
fi

if ! grep -q "email_from: \"HOTOSM Sandbox <no-reply@${DOMAIN}>\"" /app/config/settings.yml; then
  sed -i "s/email_from: \"OpenStreetMap <openstreetmap@example.com>\"/email_from: \"HOTOSM Sandbox <no-reply@${DOMAIN}>\"/" /app/config/settings.yml
fi

if ! grep -q "email_return_path: \"no-reply@${DOMAIN}\"" /app/config/settings.yml; then
  sed -i "s/email_return_path: \"openstreetmap@example.com\"/email_return_path: \"no-reply@${DOMAIN}\"/" /app/config/settings.yml
fi

echo
echo "ID Editor OAuth App Details:"
echo
echo "Client ID: $ID_EDITOR_CLIENT_ID"
echo "Client Secret: $ID_EDITOR_CLIENT_SECRET"
echo "Admin OAuth Token: $ADMIN_OAUTH_TOKEN"
echo

exec "$@"
