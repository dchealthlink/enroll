require 'bcrypt'
require 'pp'
require 'securerandom'

bugger = false
pass = false
pass_arg = ARGV.shift

if pass_arg then
    pass = pass_arg
else
    pass = SecureRandom.hex(32)
    puts 'no pass provided, making random' if bugger
end

# BCrypt::Engine.cost = 4  # default is 10
# hashed_pass = BCrypt::Password.create(pass, cost: 15)
hashed_pass = BCrypt::Password.create(pass)

puts ['plain:', pass].join(' ')
puts ['hashed:', hashed_pass].join(' ')

puts ['version:', hashed_pass.version].join(' ') if bugger
puts ['cost:', hashed_pass.cost].join(' ') if bugger
puts ['salt:', hashed_pass.salt].join(' ') if bugger
puts ['checksum:', hashed_pass.checksum].join(' ') if bugger

# this is actually comparing the password hash, and not the password string itself.
# alias_method: BCrypt::Password#is_password?(pass)

# BCrypt::Password.is_password?(pass)
pp hashed_pass == pass if bugger

puts 'check pass...' if bugger
# with the password and the salt, this .hash_secret return the password hash
# same as BCrypt::Password#to_s
hash_secret = BCrypt::Engine.hash_secret(pass, hashed_pass.salt)
puts ['Hash Secret:', hash_secret].join(' ') if bugger
hashed_pass = BCrypt::Password.new(hash_secret)
pp hashed_pass == pass if bugger


