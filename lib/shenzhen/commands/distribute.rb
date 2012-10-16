alias_command :distribute, :'distribute:testflight'

def determine_api_token!
  @api_token ||= Shenzhen::Config['API_TOKEN'] || ask('API Token:')
end

def determine_team_token!
  @team_token ||= Shenzhen::Config['TEAM_TOKEN'] || ask('Team Token:')
end
