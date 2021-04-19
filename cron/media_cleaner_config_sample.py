#----------------------------------------------------------#
# Delete media type once it has been played x days ago
#   0-365000000 - number of days to wait before deleting played media
#  -1 : to disable managing specified media type
# (-1 : default)
#----------------------------------------------------------#
not_played_age_movie=1
not_played_age_episode=1
not_played_age_video=1
not_played_age_trailer=1
not_played_age_audio=1

#----------------------------------------------------------#
# Decide if media set as a favorite should be deleted
# Favoriting a series, season, or network-channel will treat all child episodes as if they are favorites
# Favoriting an artist, album-artist, or album will treat all child tracks as if they are favorites
# Similar logic applies for other media types (episodes, trailers, etc...)
#  0 : ok to delete favorite
#  1 : do no delete favorite
# (1 : default)
#----------------------------------------------------------#
keep_favorites_movie=1
keep_favorites_episode=1
keep_favorites_video=1
keep_favorites_trailer=1
keep_favorites_audio=1

#----------------------------------------------------------#
# Advanced favorites configuration bitmask
#     Requires 'keep_favorites_*=1'
#  xxxxxxxA - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST artist listed in the track's 'artist' metadata is favorited
#  xxxxxxBx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST artist listed in the tracks's 'album artist' metadata is favorited
#  xxxxxCxx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST genre listed in the tracks's metadata is favorited
#  xxxxDxxx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST genre listed in the album's metadata is favorited
#  xxxExxxx - keep_favorites_episode must be enabled; keep episode based on if the FIRST genre listed in the series' metadata is favorited
#  xxFxxxxx - keep_favorites_movie must be enabled; keep movie based on if the FIRST genre listed in the movie's metadata is favorited
#  xGxxxxxx - reserved...
#  Hxxxxxxx - reserved...
#  0 bit - disabled
#  1 bit - enabled
# (00000001 - default)
#----------------------------------------------------------#
keep_favorites_advanced='00000001'

#----------------------------------------------------------#
# Advanced favorites any configuration bitmask
#     Requires matching bit in 'keep_favorites_advanced' bitmask is enabled
#  xxxxxxxa - xxxxxxxA must be enabled; will use ANY artists listed in the track's 'artist' metadata
#  xxxxxxbx - xxxxxxBx must be enabled; will use ANY artists listed in the track's 'album artist' metadata
#  xxxxxcxx - xxxxxCxx must be enabled; will use ANY genres listed in the track's metadata
#  xxxxdxxx - xxxxDxxx must be enabled; will use ANY genres listed in the album's metadata
#  xxxexxxx - xxxExxxx must be enabled; will use ANY genres listed in the series' metadata
#  xxfxxxxx - xxFxxxxx must be enabled; will use ANY genres listed in the movie's metadata
#  xgxxxxxx - reserved...
#  hxxxxxxx - reserved...
#  0 bit - disabled
#  1 bit - enabled
# (00000000 - default)
#----------------------------------------------------------#
keep_favorites_advanced_any='00000000'

#----------------------------------------------------------#
# Whitelisting a library folder will treat all child media as if they are favorites
# ('' - default)
#----------------------------------------------------------#
whitelisted_library_folders=''

#----------------------------------------------------------#
# 0 - Disable the ability to delete media (dry run mode)
# 1 - Enable the ability to delete media
# (0 - default)
#----------------------------------------------------------#
remove_files=1

#------------DO NOT MODIFY BELOW---------------------------#

#----------------------------------------------------------#
# Server branding chosen during setup; only used during setup
#  0 - 'emby'
#  1 - 'jellyfin'
# Server URL created during setup
# Admin username chosen during setup
# Access token requested from server during setup
# User key of account to monitor played media chosen during setup
#----------------------------------------------------------#
server_brand='jellyfin'
server_url='http://jellyfin:8096/emby'
admin_username='<>'
access_token='<>'
user_key='<>'
DEBUG=0
