#!/bin/bash

# Start web server
bundle exec rails s -d -p 3000 -b '0.0.0.0'

# Run migrations
bundle exec rails db:migrate

# Ruby script to create admin (to file)
# NOTE ID_EDITOR_REDIRECT_URI env var is injected
cat << EOF > create_admin_user.rb
unless User.exists?(email: "#{ENV['ADMIN_PASS']}")
  pass_crypt, pass_salt = PasswordHash.create("#{ENV['ADMIN_PASS']}")
  admin_user = User.create!(
      display_name: "HOTOSM",
      email: "#{ENV['ADMIN_PASS']}",
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

unless Oauth2Application.exists?(name: 'ID Dev')
  admin_user = User.find_by(email: "#{ENV['ADMIN_PASS']}")
  id_app = Oauth2Application.create!(
      owner: admin_user,
      name: 'ID Dev',
      redirect_uri: "#{ENV['ID_EDITOR_REDIRECT_URI']}",
      scopes: ['read_prefs', 'write_api'],
      confidential: false,
  )
  puts id_app.uid
  # puts id_app.secret
end
EOF

# Run script in Rails console
ID_EDITOR_CLIENT_ID=$(bundle exec rails runner create_admin_user.rb)
echo ""
echo "ID Editor Client ID:"
echo "${ID_EDITOR_CLIENT_ID}"
echo ""

# Stop web server gracefully
kill -TERM $(cat /tmp/pids/server.pid)

# Update the OpenStreetMap settings
# Further overrides can be made in a mounted settings.local.yml file
# The oauth_application var is for OSM Notes / changeset comments
# The id_application var is for ID editor
sed -i "s/#id_application: \"\"/id_application: \"${ID_EDITOR_CLIENT_ID}\"/" /app/config/settings.yml
sed -i "s/server_protocol: \"http\"/server_protocol: \"${PROTOCOL}\"/" /app/config/settings.yml
sed -i "s/server_url: \"https:\/\/www.openstreetmap.org\"/server_url: \"${DOMAIN}\"/" /app/config/settings.yml
# SMTP settings
sed -i "s/smtp_address: \"localhost\"/smtp_address: \"mail\"/" /app/config/settings.yml
sed -i "s/smtp_domain: \"localhost\"/smtp_domain: \"${DOMAIN}\"/" /app/config/settings.yml
sed -i "s/email_from: \"OpenStreetMap <openstreetmap@example.com>\"/email_from: \"OSM Dev <admin@${DOMAIN}>\"/" /app/config/settings.yml
sed -i "s/email_return_path: \"openstreetmap@example.com\"/email_return_path: \"admin@${DOMAIN}\"/" /app/config/settings.yml

# Set exec to replace shell with the command passed as arguments
exec "$@"
