import os

server_brand='emby'
server_url='http://emby:8096/emby'
admin_username=os.getenv('EMBY_USER')
admin_password_sha1=os.getenv('EMBY_PASSWD_HASH')
access_token=os.getenv('EMBY_ACCESS_TOKEN')
user_key=os.getenv('EMBY_USER_KEY')
DEBUG=0
not_played_age_movie=1
not_played_age_episode=1
not_played_age_video=1
not_played_age_trailer=-1
remove_files=1
keep_favorites_movie=1
keep_favorites_episode=1
keep_favorites_video=1
keep_favorites_trailer=1
