#!/bin/bash

# Vars
NEW_PASSWORD=${NEW_PASSWORD:-"Catchy Rockfish Bulginess Subtotal Bottling"}
OUTPUT_FILE="update_passwords.sql"

# Generate Argon2 password hash using Rails
generate_password_hash() {
    local password="$1"
    bundle exec rails runner "require 'argon2'; puts Argon2::Password.create('$password')"
}

# Generate password hash
echo "Generating password hash..."
password_crypt=$(generate_password_hash "$NEW_PASSWORD")

# Generate SQL file for updating passwords
echo "Generating SQL file: $OUTPUT_FILE"
echo "UPDATE users SET pass_crypt = '$password_crypt' WHERE email LIKE '%gis%';" > "$OUTPUT_FILE"

echo "SQL file generated successfully: $OUTPUT_FILE"
