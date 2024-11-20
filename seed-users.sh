#!/bin/bash

# NOTE this script is not used anywhere yet
# The idea is to allow for the initialisation of multiple
# users, e.g. during a mapathon.

# Vars
NUM_USERS_TO_CREATE=${NUM_USER:-10}
BASE_USERNAME=${BASE_USERNAME:-"mapper"}
BASE_EMAIL_DOMAIN=${BASE_EMAIL_DOMAIN:-"osmseed.org"}
BASE_PASSWORD=${BASE_PASSWORD:-"Catchy Rockfish Bulginess Subtotal Bottling"}
OUTPUT_FILE="insert_users.sql"

# Generate Argon2 password hash using Rails (this is slow, but works)
generate_password_hash() {
    local password="$1"
    bundle exec rails runner "require 'argon2'; puts Argon2::Password.create('$password')"
}

# Start generating the SQL file
echo "Generating SQL file: $OUTPUT_FILE"
echo "INSERT INTO users (email, display_name, email_valid, status, data_public, creation_time, creation_ip, languages, terms_agreed, consider_pd, tou_agreed, terms_seen, pass_crypt) VALUES" > "$OUTPUT_FILE"

# Loop through users
for i in $(seq -w 1 $NUM_USERS_TO_CREATE); do
    # Append current id to email and password
    email="${BASE_USERNAME}${i}@${BASE_EMAIL_DOMAIN}"
    display_name="${BASE_USERNAME}${i}"
    password="${BASE_PASSWORD}${i}"
    password_crypt=$(generate_password_hash "$password")
    
    # These are hardcoded for now
    creation_ip="172.21.0.1"
    languages="en-US,en"

    # Append SQL for this user to file
    echo "('$email', '$display_name', TRUE, 'confirmed', TRUE, NOW(), '$creation_ip', '$languages', NOW(), TRUE, NOW(), TRUE, '$password_crypt')," >> "$OUTPUT_FILE"
    echo "Created user $email"
done

# Remove the last comma and add a semicolon
sed -i '$ s/,$/;/' "$OUTPUT_FILE" || sed -i '' '$ s/,$/;/' "$OUTPUT_FILE"

echo "SQL file generated successfully: $OUTPUT_FILE"
