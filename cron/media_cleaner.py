#!/usr/bin/env python3

import urllib.request as request
import json, urllib
import traceback
import hashlib
import sys
import os
from dateutil.parser import parse
from datetime import datetime,date,timedelta,timezone

# Hash password if not hashed
#if cfg.admin_password_sha1 == '':
#     cfg.admin_password_sha1=hashlib.sha1(cfg.admin_password.encode()).hexdigest()
#auth_key=''
#print('Hash:'+ cfg.admin_password_sha1)


def convert2json(rawjson):
    #return a formatted string of the python JSON object
    ezjson = json.dumps(rawjson, sort_keys=False, indent=4)
    return(ezjson)


def print2json(rawjson):
    #create a formatted string of the python JSON object
    ezjson = convert2json(rawjson)
    print(ezjson)


#emby or jellyfin?
def get_brand():
    defaultbrand='emby'
    print('0:emby\n1:jellyfin')
    brand=input('Enter number for server branding (default ' + defaultbrand + '): ')
    if (brand == ''):
        return(defaultbrand)
    elif (brand == '0'):
        return(defaultbrand)
    elif (brand == '1'):
        return('jellyfin')
    else:
        print('Invalid choice. Default to emby.')
        return(defaultbrand)


#ip address or url?
def get_url():
    defaulturl='http://localhost'
    url=input('Enter server ip or name (default ' + defaulturl + '): ')
    if (url == ''):
        return(defaulturl)
    else:
        if (url.find('://',3,7) >= 0):
            return(url)
        else:
           #print('No http:// or https:// entered.')
           url='http://' + url
           print('Assuming server ip or name is: ' + url)
           return(url)


#http or https port?
def get_port():
    defaultport='8096'
    valid_port=False
    while (valid_port == False):
        print('If you have not explicity changed this option, press enter for default.')
        print('Space for no port.')
        port=input('Enter port (default ' + defaultport + '): ')
        if (port == ''):
            valid_port=True
            return(defaultport)
        elif (port == ' '):
            valid_port=True
            return('')
        else:
            try:
                port_float=float(port)
                if ((port_float % 1) == 0):
                    port_int=int(port_float)
                    if ((int(port_int) >= 1) and (int(port_int) <= 65535)):
                        valid_port=True
                        return(str(port_int))
                    else:
                        print('\nInvalid port. Try again.\n')
                else:
                    print('\nInvalid port. Try again.\n')
            except:
                print('\nInvalid port. Try again.\n')


#base url?
def get_base(brand):
    defaultbase='emby'
    #print('If you are using emby press enter for default.')
    if (brand == defaultbase):
        print('Using "/' + defaultbase + '" as base url')
        return(defaultbase)
    else:
        print('If you have not explicity changed this option in jellyfin, press enter for default.')
        print('For example: http://example.com/<baseurl>')
        base=input('Enter base url (default /' + defaultbase + '): ')
        if (base == ''):
            return(defaultbase)
        else:
            if (base.find('/',0,1) == 0):
                return(base[1:len(base)])
            else:
                return(base)


#admin username?
def get_admin_username():
    return(input('Enter admin username: '))


#admin password?
def get_admin_password():
    #print('Plain text password used to grab access token; hashed password stored in config file.')
    print('Plain text password used to grab access token; password not stored in config file.')
    password=input('Enter admin password: ')
    return(password)


#use of hashed password removed
#hash admin password
#def get_admin_password_sha1(password):
#    #password_sha1=password #input('Enter admin password (password will be hashed in config file): ')
#    password_sha1=hashlib.sha1(password.encode()).hexdigest()
#    return(password_sha1)


#get user input needed to build the media_cleaner_config.py file
def generate_config():
    print('-----------------------------------------------------------')
    server_brand=get_brand()

    print('-----------------------------------------------------------')
    server=get_url()
    print('-----------------------------------------------------------')
    port=get_port()
    print('-----------------------------------------------------------')
    server_base=get_base(server_brand)
    if (len(port)):
        server_url=server + ':' + port + '/' + server_base
    else:
        server_url=server + '/' + server_base
    print('-----------------------------------------------------------')

    username=get_admin_username()
    print('-----------------------------------------------------------')
    password=get_admin_password()
    print('-----------------------------------------------------------')

    auth_key=get_auth_key(server_url, username, password)
    user_key=list_users(server_url, auth_key)
    print('-----------------------------------------------------------')
    whitelist=list_library_folders(server_url, auth_key)
    print('-----------------------------------------------------------')

    not_played_age_movie="-1"
    not_played_age_episode="-1"
    not_played_age_video="-1"
    not_played_age_trailer="-1"
    not_played_age_audio="-1"

    config_file=''
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Delete media type once it has been played x days ago\n"
    config_file += "#   0-365000000 - number of days to wait before deleting played media\n"
    config_file += "#  -1 : to disable managing specified media type\n"
    config_file += "# (-1 : default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "not_played_age_movie=" + not_played_age_movie + "\n"
    config_file += "not_played_age_episode=" + not_played_age_episode + "\n"
    config_file += "not_played_age_video=" + not_played_age_video + "\n"
    config_file += "not_played_age_trailer=" + not_played_age_trailer + "\n"
    config_file += "not_played_age_audio=" + not_played_age_audio + "\n"
    #config_file += "not_played_age_tvchannel=" + not_played_age_tvchannel + "\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Decide if media set as a favorite should be deleted\n"
    config_file += "# Favoriting a series, season, or network-channel will treat all child episodes as if they are favorites\n"
    config_file += "# Favoriting an artist, album-artist, or album will treat all child tracks as if they are favorites\n"
    config_file += "# Similar logic applies for other media types (episodes, trailers, etc...)\n"
    config_file += "#  0 : ok to delete favorite\n"
    config_file += "#  1 : do no delete favorite\n"
    config_file += "# (1 : default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "keep_favorites_movie=1\n"
    config_file += "keep_favorites_episode=1\n"
    config_file += "keep_favorites_video=1\n"
    config_file += "keep_favorites_trailer=1\n"
    config_file += "keep_favorites_audio=1\n"
    #config_file += "keep_favorites_tvchannel=1\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Advanced favorites configuration bitmask\n"
    config_file += "#     Requires 'keep_favorites_*=1'\n"
    config_file += "#  xxxxxxxA - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST artist listed in the track's 'artist' metadata is favorited\n"
    config_file += "#  xxxxxxBx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST artist listed in the tracks's 'album artist' metadata is favorited\n"
    config_file += "#  xxxxxCxx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST genre listed in the tracks's metadata is favorited\n"
    config_file += "#  xxxxDxxx - keep_favorites_audio must be enabled; keep audio tracks based on if the FIRST genre listed in the album's metadata is favorited\n"
    config_file += "#  xxxExxxx - keep_favorites_episode must be enabled; keep episode based on if the FIRST genre listed in the series' metadata is favorited\n"
    config_file += "#  xxFxxxxx - keep_favorites_movie must be enabled; keep movie based on if the FIRST genre listed in the movie's metadata is favorited\n"
    config_file += "#  xGxxxxxx - reserved...\n"
    config_file += "#  Hxxxxxxx - reserved...\n"
    config_file += "#  0 bit - disabled\n"
    config_file += "#  1 bit - enabled\n"
    config_file += "# (00000001 - default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "keep_favorites_advanced='00000001'\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Advanced favorites any configuration bitmask\n"
    config_file += "#     Requires matching bit in 'keep_favorites_advanced' bitmask is enabled\n"
    config_file += "#  xxxxxxxa - xxxxxxxA must be enabled; will use ANY artists listed in the track's 'artist' metadata\n"
    config_file += "#  xxxxxxbx - xxxxxxBx must be enabled; will use ANY artists listed in the track's 'album artist' metadata\n"
    config_file += "#  xxxxxcxx - xxxxxCxx must be enabled; will use ANY genres listed in the track's metadata\n"
    config_file += "#  xxxxdxxx - xxxxDxxx must be enabled; will use ANY genres listed in the album's metadata\n"
    config_file += "#  xxxexxxx - xxxExxxx must be enabled; will use ANY genres listed in the series' metadata\n"
    config_file += "#  xxfxxxxx - xxFxxxxx must be enabled; will use ANY genres listed in the movie's metadata\n"
    config_file += "#  xgxxxxxx - reserved...\n"
    config_file += "#  hxxxxxxx - reserved...\n"
    config_file += "#  0 bit - disabled\n"
    config_file += "#  1 bit - enabled\n"
    config_file += "# (00000000 - default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "keep_favorites_advanced_any='00000000'\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Whitelisting a library folder will treat all child media as if they are favorites\n"
    config_file += "# ('' - default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "whitelisted_library_folders='" + whitelist + "'\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# 0 - Disable the ability to delete media (dry run mode)\n"
    config_file += "# 1 - Enable the ability to delete media\n"
    config_file += "# (0 - default)\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "remove_files=0\n"
    #config_file += "#----------------------------------------------------------#\n"
    config_file += "\n"
    config_file += "#------------DO NOT MODIFY BELOW---------------------------#\n"
    config_file += "\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "# Server branding chosen during setup; only used during setup\n"
    config_file += "#  0 - 'emby'\n"
    config_file += "#  1 - 'jellyfin'\n"
    config_file += "# Server URL created during setup\n"
    config_file += "# Admin username chosen during setup\n"
    config_file += "# Access token requested from server during setup\n"
    config_file += "# User key of account to monitor played media chosen during setup\n"
    config_file += "#----------------------------------------------------------#\n"
    config_file += "server_brand='" + server_brand + "'\n"
    config_file += "server_url='" + server_url + "'\n"
    config_file += "admin_username='" + username + "'\n"
    config_file += "access_token='" + auth_key + "'\n"
    config_file += "user_key='" + user_key + "'\n"
    config_file += "DEBUG=0\n"
    #config_file += "#----------------------------------------------------------#"

    #Create config file next to the script even when cwd (Current Working Directory) is not the same
    cwd = os.getcwd()
    script_dir = os.path.dirname(__file__)
    if (script_dir == ''):
        #script must have been run from the cwd
        #set script_dir to cwd (aka this directory) to prevent error when attempting to change to '' (aka a blank directory)
        script_dir=cwd
    os.chdir(script_dir)
    f = open("media_cleaner_config.py", "w")
    f.write(config_file)
    f.close()
    os.chdir(cwd)

    print('\n\n-----------------------------------------------------------')
    print('Config file is not setup to find played media.')
    print('-----------------------------------------------------------')
    print('To find played media open media_cleaner_config.py in a text editor:')
    print('    Set \'not_played_age_movie\' to zero or a positive number')
    print('    Set \'not_played_age_episode\' to zero or a positive number')
    print('    Set \'not_played_age_video\' to zero or a positive number')
    print('    Set \'not_played_age_trailer\' to zero or a positive number')
    print('    Set \'not_played_age_audio\' to zero or a positive number')
    print('-----------------------------------------------------------')
    print('Config file is in dry run mode to prevent deleting media.')
    print('-----------------------------------------------------------')
    print('To delete media open media_cleaner_config.py in a text editor:')
    print('    Set \'remove_files=1\' in media_cleaner_config.py')
    print('-----------------------------------------------------------')
    print('Edit the config file and try running again.')
    print('-----------------------------------------------------------')


#api call to delete items
def delete_item(itemID):
    url=url=cfg.server_url + '/Items/' + itemID + '?api_key=' + cfg.access_token
    req = request.Request(url,method='DELETE')
    if bool(cfg.DEBUG):
        #DEBUG
        print(itemID)
        print(url)
        print(req)
    if bool(cfg.remove_files):
        try:
            request.urlopen(req)
        except Exception:
            print('generic exception: ' + traceback.format_exc())
    else:
        return


#api call to get admin account authentication token
def get_auth_key(server_url, username, password):
    #login info
    values = {'Username' : username, 'Pw' : password}
    #DATA = urllib.parse.urlencode(values)
    #DATA = DATA.encode('ascii')
    DATA = convert2json(values)
    DATA = DATA.encode('utf-8')

    headers = {'X-Emby-Authorization' : 'Emby UserId="'+ username  +'", Client="media_cleaner", Device="media_cleaner", DeviceId="media_cleaner", Version="0.4", Token=""', 'Content-Type' : 'application/json'}

    req = request.Request(url=server_url + '/Users/AuthenticateByName', data=DATA, method='POST', headers=headers)

    with request.urlopen(req) as response:
        if response.getcode() == 200:
            source = response.read()
            data = json.loads(source)

            #DEBUG
            #print('get auth key data)
            #print2json(data)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    return(data['AccessToken'])


#api call to get all user accounts
#then choose account this script will use to delete played media
#choosen account does NOT need to have "Allow Media Deletion From" enabled
def list_users(server_url, auth_key):
    #Get all users
    with request.urlopen(server_url + '/Users?api_key=' + auth_key) as response:
        if response.getcode() == 200:
            source = response.read()
            data = json.loads(source)

            #DEBUG
            #print('list users')
            #print2json(data)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    valid_user=False
    while (valid_user == False):
        i=0
        for user in data:
            print(str(i) +' - '+ user['Name'] + ' - ' + user['Id'])
            i += 1

        user_number=input('Enter number of user to track: ')

        try:
            user_number_float=float(user_number)
            if ((user_number_float % 1) == 0):
                user_number_int=int(user_number_float)
                if ((user_number_int >= 0) and (user_number_int < i)):
                    valid_user=True
                else:
                    print('\nInvalid value. Try again.\n')
            else:
                print('\nInvalid value. Try again.\n')
        except:
            print('\nInvalid value. Try again.\n')

    userID=data[user_number_int]['Id']
    return(userID)


#api call to get library folders
#then choose which folders to whitelist
def list_library_folders(server_url, auth_key):
    #get all library paths
    with request.urlopen(server_url + '/Library/VirtualFolders?api_key=' + auth_key) as response:
        if response.getcode() == 200:
            source = response.read()
            data = json.loads(source)

            #DEBUG
            #print('list library folders')
            #print2json(data)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    #define empty dictionary
    libraryfolders_dict={}
    #define empty set
    libraryfolders_set=set()

    stop_loop=False
    while (stop_loop == False):
        i=0
        for path in data:
            for subpath in range(len(path['LibraryOptions']['PathInfos'])):
                if ('NetworkPath' in path['LibraryOptions']['PathInfos'][subpath]):
                    if not (path['LibraryOptions']['PathInfos'][subpath]['NetworkPath'] in libraryfolders_set):
                        print(str(i) + ' - ' + path['LibraryOptions']['PathInfos'][subpath]['Path'] + ' - (' + path['LibraryOptions']['PathInfos'][subpath]['NetworkPath'] +')')
                        libraryfolders_dict[i]=path['LibraryOptions']['PathInfos'][subpath]['NetworkPath']
                    else:
                        #show blank entry
                        print(str(i) + ' - ')
                else: #('Path' in path['LibraryOptions']['PathInfos'][subpath]):
                    if not(path['LibraryOptions']['PathInfos'][subpath]['Path'] in libraryfolders_set):
                        print(str(i) + ' - ' + path['LibraryOptions']['PathInfos'][subpath]['Path'])
                        libraryfolders_dict[i]=path['LibraryOptions']['PathInfos'][subpath]['Path']
                    else:
                        #show blank entry
                        print(str(i) + ' - ')
                i += 1

        if (i >= 1):
            print('Enter number of library folder to whitelist.')
            print('Media in whitelisted library folders will NOT be deleted.')
            path_number=input('Leave blank for none or when finished: ')
        else:
            path_number=''

        try:
            if (path_number == ''):
                stop_loop=True
                print('')
            else:
                path_number_float=float(path_number)
                if ((path_number_float % 1) == 0):
                    path_number_int=int(path_number_float)
                    if ((path_number_int >= 0) and (path_number_int < i)):
                        libraryfolders_set.add(libraryfolders_dict[path_number_int])
                        if (len(libraryfolders_set) >= i):
                            stop_loop=True
                            print('')
                        else:
                            stop_loop=False
                            print('')

                        #DEBUG
                        #print('selected library folders')
                        #print(libraryfolders_set)
                    else:
                        print('\nInvalid value. Try again.\n')
                else:
                    print('\nInvalid value. Try again.\n')
        except:
            print('\nInvalid value. Try again.\n')

    if (libraryfolders_set == set()):
        return('')
    else:
        i=0
        whitelistpaths=''
        for libfolders in libraryfolders_set:
            if (i == 0):
                #libfolders = libfolders.replace('\"','\\\"')
                whitelistpaths = libfolders.replace('\'','\\\'')
            else:
                #libfolders = libfolders.replace('\"','\\\"')
                whitelistpaths = libfolders.replace('\'','\\\'') + ',' + whitelistpaths
            i += 1

        return(whitelistpaths)


#Get count of days since last played
def get_days_since_played(date_last_played):
    #Get current time
    date_time_now = datetime.utcnow()

    #Keep the year, month, day, hour, minute, and seconds
      #split date_last_played after seconds
    try:
        split_date_micro_tz = date_last_played.split(".")
        date_time_last_played = datetime.strptime(date_last_played, '%Y-%m-%dT%H:%M:%S.' + split_date_micro_tz[1])
    except (ValueError):
        date_time_last_played = 'unknown date time format'

    if bool(cfg.DEBUG):
        #DEBUG
        print(date_time_last_played)

    if not (date_time_last_played == 'unknown date time format'):
        date_time_delta = date_time_now - date_time_last_played
        s_date_time_delta = str(date_time_delta)
        days_since_played = s_date_time_delta.split(' day')[0]
        if ':' in days_since_played:
            days_since_played = 'Played <1 day ago'
        elif days_since_played == '1':
            days_since_played = 'Played ' + days_since_played + ' day ago'
        else:
            days_since_played = 'Played ' + days_since_played + ' days ago'
    else:
        days_since_played='0'
    return(days_since_played)


#get season and episode numbers
def get_season_episode(season_number, episode_number):
    season_num = str(season_number)
    season_num_len=len(str(season_number))

    episode_num = str(episode_number)
    episode_num_len=len(str(episode_num))

    #at the least; print season.episode with 2-digits zero padded
    #if season or episode has more than 2-digits print x-digits zero padded
    if (season_num_len <= 2) and (episode_num_len <= 2):
        season_num = season_num.zfill(2)
        episode_num = episode_num.zfill(2)
    elif (season_num_len >= episode_num_len):
        season_num = season_num.zfill(season_num_len)
        episode_num = episode_num.zfill(season_num_len)
    else: #(season_num_len < episode_num_len):
        season_num = season_num.zfill(episode_num_len)
        episode_num = episode_num.zfill(episode_num_len)

    season_episode = 's' + season_num + '.e' + episode_num
    return(season_episode)


#get additional item info needed to determine if parent of item is favorite
#get additional item info needed to determine if media item is in whitelist
def get_additional_item_info(server_url, user_key, itemId, auth_key):
    #Get additonal item information
    url=server_url + '/Users/' + user_key  + '/Items/' + str(itemId) + '?fields=SeriesStudio,Studios,Genres&api_key=' + auth_key

    if bool(cfg.DEBUG):
        #DEBUG
        print('-----------------------------------------------------------')
        print(url)
    with request.urlopen(url) as response:
        if response.getcode() == 200:
            source = response.read()
            itemInfo = json.loads(source)
            if bool(cfg.DEBUG):
                #DEBUG
                print('get_additional_item_info')
                print2json(itemInfo)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    return(itemInfo)

#get additional channel/network/studio info needed to determine if item is favorite
def get_studio_item_info(server_url, user_key, studioName, auth_key):
    #Encode studio name
    networkchannel_name=urllib.parse.quote(studioName)

    #Get studio item information
    url=server_url + '/Studios/' + networkchannel_name + '?userId=' + user_key + '&api_key=' + auth_key

    if bool(cfg.DEBUG):
        #DEBUG
        print('-----------------------------------------------------------')
        print(url)
    with request.urlopen(url) as response:
        if response.getcode() == 200:
            source = response.read()
            itemInfo = json.loads(source)
            if bool(cfg.DEBUG):
                #DEBUG
                print('get_studio_item_info')
                print2json(itemInfo)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    return(itemInfo)

#determine if track, album, or artist are set to favorite
def get_isfav_MUSICtaa(isfav_MUSICtaa, item, server_url, user_key, auth_key):
    #Set bitmasks
    adv_settings=int(cfg.keep_favorites_advanced, 2)
    adv_settings_any=int(cfg.keep_favorites_advanced_any, 2)
    trackartist_mask=int('00000001', 2)
    albumartist_mask=int('00000010', 2)
    trackgenre_mask=int('00000100', 2)
    albumgenre_mask=int('00001000', 2)
    trackartist_any_mask=trackartist_mask
    albumartist_any_mask=albumartist_mask
    trackgenre_any_mask=trackgenre_mask
    albumgenre_any_mask=albumgenre_mask

### Track #########################################################################################

    #Check if track's favorite value already exists in dictionary
    if not item['Id'] in isfav_MUSICtaa['track']:
        #Store if this track is marked as a favorite
        isfav_MUSICtaa['track'][item['Id']] = item['UserData']['IsFavorite']

    #Check if bitmask for favotires by track genre is enabled
    if (adv_settings & trackgenre_mask):
        #Check if bitmask for any or first track genre is enabled
        if not (adv_settings_any & trackgenre_any_mask):
            genre_track_item_info = get_additional_item_info(server_url, user_key, item['GenreItems'][0]['Id'], auth_key)
            #Check if track genre's favorite value already exists in dictionary
            if not item['GenreItems'][0]['Id'] in isfav_MUSICtaa['trackgenre']:
                #Store if first track genre is marked as favorite
                isfav_MUSICtaa['trackgenre'][item['GenreItems'][0]['Id']] = genre_track_item_info['UserData']['IsFavorite']
        else:
            for trackgenre in range(len(item['GenreItems'])):
                genre_track_item_info = get_additional_item_info(server_url, user_key, item['GenreItems'][trackgenre]['Id'], auth_key)
                #Check if track genre's favorite value already exists in dictionary
                if not item['GenreItems'][trackgenre]['Id'] in isfav_MUSICtaa['trackgenre']:
                    #Store if any track genre is marked as a favorite
                    isfav_MUSICtaa['trackgenre'][item['GenreItems'][trackgenre]['Id']] = genre_track_item_info['UserData']['IsFavorite']

### End Track #####################################################################################

### Album #########################################################################################

    album_item_info = get_additional_item_info(server_url, user_key, item['AlbumId'], auth_key)
    #Check if album's favorite value already exists in dictionary
    if not item['AlbumId'] in isfav_MUSICtaa['album']:
        #Store if the album is marked as a favorite
        isfav_MUSICtaa['album'][item['AlbumId']] = album_item_info['UserData']['IsFavorite']

    #Check if bitmask for favotires by album genre is enabled
    if (adv_settings & albumgenre_mask):
        #Check if bitmask for any or first album genre is enabled
        if not (adv_settings_any & albumgenre_any_mask):
            genre_album_item_info = get_additional_item_info(server_url, user_key, album_item_info['GenreItems'][0]['Id'], auth_key)
            #Check if album genre's favorite value already exists in dictionary
            if not album_item_info['GenreItems'][0]['Id'] in isfav_MUSICtaa['albumgenre']:
                #Store if first album genre is marked as favorite
                isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][0]['Id']] = genre_album_item_info['UserData']['IsFavorite']
        else:
            for albumgenre in range(len(album_item_info['GenreItems'])):
                genre_album_item_info = get_additional_item_info(server_url, user_key, album_item_info['GenreItems'][albumgenre]['Id'], auth_key)
                #Check if album genre's favorite value already exists in dictionary
                if not album_item_info['GenreItems'][albumgenre]['Id'] in isfav_MUSICtaa['albumgenre']:
                    #Store if any album genre is marked as a favorite
                    isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][albumgenre]['Id']] = genre_album_item_info['UserData']['IsFavorite']

### End Album #####################################################################################

### Artist ########################################################################################

    #Check if bitmask for favorites by track artist is enabled
    if (adv_settings & trackartist_mask):
        #Check if bitmask for any or first track artist is enabled
        if not (adv_settings_any & trackartist_any_mask):
            artist_item_info = get_additional_item_info(server_url, user_key, item['ArtistItems'][0]['Id'], auth_key)
            #Check if artist's favorite value already exists in dictionary
            if not item['ArtistItems'][0]['Id'] in isfav_MUSICtaa['artist']:
                #Store if first track artist is marked as favorite
                isfav_MUSICtaa['artist'][item['ArtistItems'][0]['Id']] = artist_item_info['UserData']['IsFavorite']
        else:
            for artist in range(len(item['ArtistItems'])):
                artist_item_info = get_additional_item_info(server_url, user_key, item['ArtistItems'][artist]['Id'], auth_key)
                #Check if artist's favorite value already exists in dictionary
                if not item['ArtistItems'][artist]['Id'] in isfav_MUSICtaa['artist']:
                    #Store if any track artist is marked as a favorite
                    isfav_MUSICtaa['artist'][item['ArtistItems'][artist]['Id']] = artist_item_info['UserData']['IsFavorite']

    #Check if bitmask for favotires by album artist is enabled
    if (adv_settings & albumartist_mask):
        #Check if bitmask for any or first album artist is enabled
        if not (adv_settings_any & albumartist_any_mask):
            artist_item_info = get_additional_item_info(server_url, user_key, item['AlbumArtists'][0]['Id'], auth_key)
            #Check if artist's favorite value already exists in dictionary
            if not item['AlbumArtists'][0]['Id'] in isfav_MUSICtaa['artist']:
                #Store if first album artist is marked as favorite
                isfav_MUSICtaa['artist'][item['AlbumArtists'][0]['Id']] = artist_item_info['UserData']['IsFavorite']
        else:
            for albumartist in range(len(item['AlbumArtists'])):
                artist_item_info = get_additional_item_info(server_url, user_key, item['AlbumArtists'][albumartist]['Id'], auth_key)
                #Check if artist's favorite value already exists in dictionary
                if not item['AlbumArtists'][albumartist]['Id'] in isfav_MUSICtaa['artist']:
                    #Store if any album artist is marked as a favorite
                    isfav_MUSICtaa['artist'][item['AlbumArtists'][albumartist]['Id']] = artist_item_info['UserData']['IsFavorite']

### End Artist ####################################################################################

    if bool(cfg.DEBUG):
        #DEBUG
        print('-----------------------------------------------------------')
        print('     Track is favorite: ' + str(isfav_MUSICtaa['track'][item['Id']]))
        print('     Album is favorite: ' + str(isfav_MUSICtaa['album'][item['AlbumId']]))
        if (adv_settings & trackartist_mask):
            if not (adv_settings_any & trackartist_any_mask):
                print(' TrkArtist is favorite: ' + str(isfav_MUSICtaa['artist'][item['ArtistItems'][0]['Id']]))
            else:
                i=0
                for artist in range(len(item['ArtistItems'])):
                    print('TrkArtist' + str(i) + ' is favorite: ' + str(isfav_MUSICtaa['artist'][item['ArtistItems'][artist]['Id']]))
                    i+=1
        if (adv_settings & albumartist_mask):
            if not (adv_settings_any & albumartist_any_mask):
                print(' AlbArtist is favorite: ' + str(isfav_MUSICtaa['artist'][item['AlbumArtists'][0]['Id']]))
            else:
                i=0
                for albumartist in range(len(item['AlbumArtists'])):
                    print('AlbArtist' + str(i) + ' is favorite: ' + str(isfav_MUSICtaa['artist'][item['AlbumArtists'][albumartist]['Id']]))
                    i+=1
        if (adv_settings & trackgenre_mask):
            if not (adv_settings_any & trackgenre_any_mask):
                print('  TrkGenre is favorite: ' + str(isfav_MUSICtaa['trackgenre'][item['GenreItems'][0]['Id']]))
            else:
                i=0
                for trackgenre in range(len(item['GenreItems'])):
                    print(' TrkGenre' + str(i) + ' is favorite: ' + str(isfav_MUSICtaa['trackgenre'][item['GenreItems'][trackgenre]['Id']]))
                    i+=1
        if (adv_settings & albumgenre_mask):
            if not (adv_settings_any & albumgenre_any_mask):
                print('  AlbGenre is favorite: ' + str(isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][0]['Id']]))
            else:
                i=0
                for albumgenre in range(len(album_item_info['GenreItems'])):
                    print(' AlbGenre' + str(i) + ' is favorite: ' + str(isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][albumgenre]['Id']]))
                    i+=1

    #Check if track or album was stored as a favorite
    itemisfav_MUSICtrackalbum=False
    if (
       (isfav_MUSICtaa['track'][item['Id']]) or
       (isfav_MUSICtaa['album'][item['AlbumId']])
       ):
        #Either the track or album was stored as a favorite
        itemisfav_MUSICtrackalbum=True

    #Check if track artist was stored as a favorite
    itemisfav_MUSICartist=False
    if (adv_settings & trackartist_mask):
        if not (adv_settings_any & trackartist_any_mask):
            if (isfav_MUSICtaa['artist'][item['ArtistItems'][0]['Id']]):
                itemisfav_MUSICartist=True
        else:
            #Check if any track artist was stored as a favorite
            for artist in range(len(item['ArtistItems'])):
                if (isfav_MUSICtaa['artist'][item['ArtistItems'][artist]['Id']]):
                    itemisfav_MUSICartist=True

    #Check if album artist was stored as a favorite
    itemisfav_MUSICalbumartist=False
    if (adv_settings & albumartist_mask):
        if not (adv_settings_any & albumartist_any_mask):
            if (isfav_MUSICtaa['artist'][item['AlbumArtists'][0]['Id']]):
                itemisfav_MUSICalbumartist=True
        else:
            #Check if any album artist was stored as a favorite
            for albumartist in range(len(item['AlbumArtists'])):
                if (isfav_MUSICtaa['artist'][item['AlbumArtists'][albumartist]['Id']]):
                    itemisfav_MUSICalubmartist=True

    #Check if track genre was stored as a favorite
    itemisfav_MUSICtrackgenre=False
    if (adv_settings & trackgenre_mask):
        if not (adv_settings_any & trackgenre_any_mask):
            if (isfav_MUSICtaa['trackgenre'][item['GenreItems'][0]['Id']]):
                itemisfav_MUSICtrackgenre=True
        else:
            #Check if any track genre was stored as a favorite
            for trackgenre in range(len(item['GenreItems'])):
                if (isfav_MUSICtaa['trackgenre'][item['GenreItems'][trackgenre]['Id']]):
                    itemisfav_MUSICtrackgenre=True

    #Check if album genre was stored as a favorite
    itemisfav_MUSICalbumgenre=False
    if (adv_settings & albumgenre_mask):
        if not (adv_settings_any & albumgenre_any_mask):
            if (isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][0]['Id']]):
                itemisfav_MUSICalbumgenre=True
        else:
            #Check if any album genre was stored as a favorite
            for albumgenre in range(len(album_item_info['GenreItems'])):
                if (isfav_MUSICtaa['albumgenre'][album_item_info['GenreItems'][albumgenre]['Id']]):
                    itemisfav_MUSICalbumgenre=True

    #Check if track, album, or artist are a favorite
    itemisfav_MUSICtaa=False
    if (
       (itemisfav_MUSICtrackalbum) or
       (itemisfav_MUSICartist) or
       (itemisfav_MUSICalbumartist) or
       (itemisfav_MUSICtrackgenre) or
       (itemisfav_MUSICalbumgenre)
       ):
        #Either the track, album, artist(s), track genre(s), or album genre(s) are set as a favorite
        itemisfav_MUSICtaa=True

    return(itemisfav_MUSICtaa)

#determine if episode, season, series, or network are set to favorite
def get_isfav_TVessn(isfav_TVessn, item, server_url, user_key, auth_key):
    adv_settings=int(cfg.keep_favorites_advanced, 2)
    adv_settings_any=int(cfg.keep_favorites_advanced_any, 2)
    seriesgenre_mask=int('00010000', 2)
    seriesgenre_any_mask=seriesgenre_mask

### Episode #######################################################################################

    #Check if episode's favorite value already exists in dictionary
    if not item['Id'] in isfav_TVessn['episode']:
        #Store if this episode is marked as a favorite
        isfav_TVessn['episode'][item['Id']] = item['UserData']['IsFavorite']

### End Episode ###################################################################################

### Season ########################################################################################

    #Check if season's favorite value already exists in dictionary
    if not item['SeasonId'] in isfav_TVessn['season']:
        #Store if the season is marked as a favorite
        isfav_TVessn['season'][item['SeasonId']] = get_additional_item_info(server_url, user_key, item['SeasonId'], auth_key)['UserData']['IsFavorite']

### End Season ####################################################################################

### Series ########################################################################################

    series_item_info = get_additional_item_info(server_url, user_key, item['SeriesId'], auth_key)
    #Check if series' favorite value already exists in dictionary
    if not item['SeriesId'] in isfav_TVessn['series']:
        #Store if the series is marked as a favorite
        isfav_TVessn['series'][item['SeriesId']] = series_item_info['UserData']['IsFavorite']

    #Check if bitmask for favotires by series genre is enabled
    if (adv_settings & seriesgenre_mask):
        #Check if bitmask for any or first series genre is enabled
        if not (adv_settings_any & seriesgenre_any_mask):
            genre_series_item_info = get_additional_item_info(server_url, user_key, series_item_info['GenreItems'][0]['Id'], auth_key)
            #Check if series genre's favorite value already exists in dictionary
            if not series_item_info['GenreItems'][0]['Id'] in isfav_TVessn['seriesgenre']:
                #Store if first series genre is marked as favorite
                isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][0]['Id']] = genre_series_item_info['UserData']['IsFavorite']
        else:
            for seriesgenre in range(len(series_item_info['GenreItems'])):
                genre_series_item_info = get_additional_item_info(server_url, user_key, series_item_info['GenreItems'][seriesgenre]['Id'], auth_key)
                #Check if series genre's favorite value already exists in dictionary
                if not series_item_info['GenreItems'][seriesgenre]['Id'] in isfav_TVessn['seriesgenre']:
                    #Store if any series genre is marked as a favorite
                    isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][seriesgenre]['Id']] = genre_series_item_info['UserData']['IsFavorite']

### End Series ####################################################################################

### Network #######################################################################################

    #Check if network's favorite value already exists in dictionary
    if not item['SeriesStudio'] in isfav_TVessn['networkchannel']:
        #Store if the channel/network/studio is marked as a favorite
        isfav_TVessn['networkchannel'][item['SeriesStudio']] = get_studio_item_info(server_url, user_key, item['SeriesStudio'], auth_key)['UserData']['IsFavorite']

### End Network ###################################################################################

    if bool(cfg.DEBUG):
        #DEBUG
        print('-----------------------------------------------------------')
        print('  Episode is favorite: ' + str(isfav_TVessn['episode'][item['Id']]))
        print('   Season is favorite: ' + str(isfav_TVessn['season'][item['SeasonId']]))
        print('   Series is favorite: ' + str(isfav_TVessn['series'][item['SeriesId']]))
        print('  Network is favorite: ' + str(isfav_TVessn['networkchannel'][item['SeriesStudio']]))
        if (adv_settings & seriesgenre_mask):
            if not (adv_settings_any & seriesgenre_any_mask):
                print(' SerGenre is favorite: ' + str(isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][0]['Id']]))
            else:
                i=0
                for seriesgenre in range(len(series_item_info['GenreItems'])):
                    print('SerGenre' + str(i) + ' is favorite: ' + str(isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][seriesgenre]['Id']]))
                    i+=1

    #Check if episode, season, or series are a favorite
    itemisfav_TVepiseasernet=False
    if (
       (isfav_TVessn['episode'][item['Id']]) or
       (isfav_TVessn['season'][item['SeasonId']]) or
       (isfav_TVessn['series'][item['SeriesId']]) or
       (isfav_TVessn['networkchannel'][item['SeriesStudio']]) #or
       ):
        #Either the episode, season, series, or network are set as a favorite
        itemisfav_TVepiseasernet=True

    #Check if track genre was stored as a favorite
    itemisfav_TVseriesgenre=False
    if (adv_settings & seriesgenre_mask):
        if not (adv_settings_any & seriesgenre_any_mask):
            if (isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][0]['Id']]):
                itemisfav_TVseriesgenre=True
        else:
            #Check if any track genre was stored as a favorite
            for seriesgenre in range(len(series_item_info['GenreItems'])):
                if (isfav_TVessn['seriesgenre'][series_item_info['GenreItems'][seriesgenre]['Id']]):
                    itemisfav_TVseriesgenre=True

    #Check if episode, season, series, series genre(s), or network/channel are a favorite
    itemisfav_TVessn=False
    if (
       (itemisfav_TVepiseasernet) or
       (itemisfav_TVseriesgenre)
       ):
        #Either the episode, season, series, series genre(s), or network/channel are set as a favorite
        itemisfav_TVessn=True

    return(itemisfav_TVessn)


#determine if movie is set to favorite
def get_isfav_MOVIE(isfav_MOVIE, item, server_url, user_key, auth_key):
    adv_settings=int(cfg.keep_favorites_advanced, 2)
    adv_settings_any=int(cfg.keep_favorites_advanced_any, 2)
    moviegenre_mask=int('00100000', 2)
    moviegenre_any_mask=moviegenre_mask

### Movie #######################################################################################

    #Check if movie's favorite value already exists in dictionary
    if not item['Id'] in isfav_MOVIE['movie']:
        #Store if this movie is marked as a favorite
        isfav_MOVIE['movie'][item['Id']] = item['UserData']['IsFavorite']

    #Check if bitmask for favotires by movie genre is enabled
    if (adv_settings & moviegenre_mask):
        #Check if bitmask for any or first movie genre is enabled
        if not (adv_settings_any & moviegenre_any_mask):
            genre_movie_item_info = get_additional_item_info(server_url, user_key, item['GenreItems'][0]['Id'], auth_key)
            #Check if movie genre's favorite value already exists in dictionary
            if not item['GenreItems'][0]['Id'] in isfav_MOVIE['moviegenre']:
                #Store if first movie genre is marked as favorite
                isfav_MOVIE['moviegenre'][item['GenreItems'][0]['Id']] = genre_movie_item_info['UserData']['IsFavorite']
        else:
            for moviegenre in range(len(item['GenreItems'])):
                genre_movie_item_info = get_additional_item_info(server_url, user_key, item['GenreItems'][moviegenre]['Id'], auth_key)
                #Check if movie genre's favorite value already exists in dictionary
                if not item['GenreItems'][moviegenre]['Id'] in isfav_MOVIE['moviegenre']:
                    #Store if any movie genre is marked as a favorite
                    isfav_MOVIE['moviegenre'][item['GenreItems'][moviegenre]['Id']] = genre_movie_item_info['UserData']['IsFavorite']

### End Movie ###################################################################################

    if bool(cfg.DEBUG):
        #DEBUG
        print('-----------------------------------------------------------')
        print('    Movie is favorite: ' + str(isfav_MOVIE['movie'][item['Id']]))
        if (adv_settings & moviegenre_mask):
            if not (adv_settings_any & moviegenre_any_mask):
                print(' MovGenre is favorite: ' + str(isfav_MOVIE['moviegenre'][item['GenreItems'][0]['Id']]))
            else:
                i=0
                for moviegenre in range(len(item['GenreItems'])):
                    print('MovGenre' + str(i) + ' is favorite: ' + str(isfav_MOVIE['moviegenre'][item['GenreItems'][moviegenre]['Id']]))
                    i+=1

    #Check if movie is a favorite
    itemisfav_MOVIEmovie=False
    if (
       (isfav_MOVIE['movie'][item['Id']])
       ):
        #Movie is set as a favorite
        itemisfav_MOVIEmovie=True

    #Check if movie genre was stored as a favorite
    itemisfav_MOVIEgenre=False
    if (adv_settings & moviegenre_mask):
        if not (adv_settings_any & moviegenre_any_mask):
            if (isfav_MOVIE['moviegenre'][item['GenreItems'][0]['Id']]):
                itemisfav_MOVIEgenre=True
        else:
            #Check if any movie genre was stored as a favorite
            for moviegenre in range(len(item['GenreItems'])):
                if (isfav_MOVIE['moviegenre'][item['GenreItems'][moviegenre]['Id']]):
                    itemisfav_MOVIEgenre=True

    #Check if movie or movie genre(s) are a favorite
    itemisfav_MOVIE=False
    if (
       (itemisfav_MOVIEmovie) or
       (itemisfav_MOVIEgenre)
       ):
        #Either the movie or movie genre(s) are set as a favorite
        itemisfav_MOVIE=True

    return(itemisfav_MOVIE)


#determine if media item is in whitelisted folder
def get_iswhitelisted(itemPath):
    #read whitelist configuration variable
    whitelist=cfg.whitelisted_library_folders
    whitelistentries=whitelist.split(',')

    #determine if media item's path matches one of the whitelist folders
    item_is_whitelisted=False
    for path in whitelistentries:
        if not (path == ''):
            if (itemPath.startswith(path)):
                item_is_whitelisted=True

                if bool(cfg.DEBUG):
                    #DEBUG
                    print('whitelist folder comparison')
                    print(path + ' : ' + itemPath)

                return(item_is_whitelisted)

    return(item_is_whitelisted)


#get played media items; track media items ready to be deleted
def get_items(server_url, user_key, auth_key):
    #Get list of all played items
    print('')
    print('-----------------------------------------------------------')
    print('Start...')
    print('Cleaning media for server at: ' + server_url)
    print('-----------------------------------------------------------')
    print('\n')
    print('-----------------------------------------------------------')
    print('Get List Of Played Media:')
    print('-----------------------------------------------------------')
    if (
       (cfg.not_played_age_movie == -1) and
       (cfg.not_played_age_episode == -1) and
       (cfg.not_played_age_video == -1) and
       (cfg.not_played_age_trailer == -1) and
       (cfg.not_played_age_audio == -1)
       ):
        print('* ATTENTION!!!                             *')
        print('* No media types are being monitored.      *')
        print('* not_played_age_movie=-1                  *')
        print('* not_played_age_episode=-1                *')
        print('* not_played_age_video=-1                  *')
        print('* not_played_age_trailer=-1                *')
        print('* not_played_age_audio=-1                  *')
        print('* Open config file in text editor.         *')
        print('* Set at least one media type to >=0 days. *')
        print('-----------------------------------------------------------')

    url=server_url + '/Users/' + user_key  + '/Items?Recursive=true&IsPlayed=true&SortBy=Type,SeriesName,AlbumArtist,ParentIndexNumber,IndexNumber,Name&SortOrder=Ascending&fields=SeriesStudio,Studios,Genres&api_key=' + auth_key

    if bool(cfg.DEBUG):
        #DEBUG
        print(url)

    with request.urlopen(url) as response:
        if response.getcode() == 200:
            source = response.read()
            data = json.loads(source)
            if bool(cfg.DEBUG):
                #DEBUG
                print('played_media_data')
                print2json(data)
        else:
            print('An error occurred while attempting to retrieve data from the API.')

    #Go through all items and get ones not played in X days
    cut_off_date_movie=datetime.now(timezone.utc) - timedelta(cfg.not_played_age_movie)
    cut_off_date_episode=datetime.now(timezone.utc) - timedelta(cfg.not_played_age_episode)
    cut_off_date_video=datetime.now(timezone.utc) - timedelta(cfg.not_played_age_video)
    cut_off_date_trailer=datetime.now(timezone.utc) - timedelta(cfg.not_played_age_trailer)
    cut_off_date_audio=datetime.now(timezone.utc) - timedelta(cfg.not_played_age_audio)
    deleteItems=[]

    #define empty dictionary for favorited Movies
    isfav_MOVIE={'movie':{},'moviegenre':{}}
    #define empty dictionary for favorited TV Series, Seasons, Episodes, and Channels/Networks
    isfav_TVessn={'episode':{},'season':{},'series':{},'networkchannel':{},'seriesgenre':{}}
    #define empty dictionary for favorited Tracks, Albums, Artists
    isfav_MUSICtaa={'track':{},'album':{},'artist':{},'trackgenre':{},'albumgenre':{}}

    #Determine if media item is to be deleted or kept
    for item in data['Items']:
        #find movie media items ready to delete
        if ((item['Type'] == 'Movie') and not (cfg.not_played_age_movie == -1)):
            #Get if movie is set as favorite
            itemisfav_MOVIE=get_isfav_MOVIE(isfav_MOVIE, item, server_url, user_key, auth_key)
            #Get if media item is whitelisted
            item_info=get_additional_item_info(server_url, user_key, item['Id'], auth_key)
            itemIsWhiteListed=get_iswhitelisted(item_info['Path'])
            if (
               (cfg.not_played_age_movie >= 0) and
               (item['UserData']['PlayCount'] >= 1) and
               (cut_off_date_movie > parse(item['UserData']['LastPlayedDate'])) and
               (not bool(cfg.keep_favorites_movie) or (not itemisfav_MOVIE)) and
               (not itemIsWhiteListed)
               ):
                try:
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Studios'][0]['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_MOVIE) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'MovieID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Delete Movie: \n' + str(item))
                print(':*[DELETE] - ' + item_details)
                deleteItems.append(item)
            else:
                try:
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Studios'][0]['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_MOVIE) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'MovieID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Keep Movie: \n' + str(item))
                print(':[KEEPING] - ' + item_details)
        #find tv-episode media items ready to delete
        elif ((item['Type'] == 'Episode') and not (cfg.not_played_age_episode == -1)):
            #Get if episode, season, or series is set as favorite
            itemisfav_TVessn=get_isfav_TVessn(isfav_TVessn, item, server_url, user_key, auth_key)
            #Get if media item is whitelisted
            item_info=get_additional_item_info(server_url, user_key, item['Id'], auth_key)
            itemIsWhiteListed=get_iswhitelisted(item_info['Path'])
            if (
               (cfg.not_played_age_episode >= 0) and
               (item['UserData']['PlayCount'] >= 1) and
               (cut_off_date_episode > parse(item['UserData']['LastPlayedDate'])) and
               (not bool(cfg.keep_favorites_episode) or (not itemisfav_TVessn)) and
               (not itemIsWhiteListed)
               ):
                try:
                    item_details=item['Type'] + ' - ' + item['SeriesName'] + ' - ' + get_season_episode(item['ParentIndexNumber'], item['IndexNumber']) + ' - ' + item['Name'] + ' - ' + item['SeriesStudio'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_TVessn) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'EpisodeID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Delete Episode: \n' + str(item))
                print(':*[DELETE] - ' + item_details)
                deleteItems.append(item)
            else:
                try:
                    item_details=item['Type'] + ' - ' + item['SeriesName'] + ' - ' + get_season_episode(item['ParentIndexNumber'], item['IndexNumber']) + ' - ' + item['Name'] + ' - ' + item['SeriesStudio'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_TVessn) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'EpisodeID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Keep Episode: \n' + str(item))
                print(':[KEEPING] - ' + item_details)
        #find video media items ready to delete
        elif ((item['Type'] == 'Video') and not (cfg.not_played_age_video == -1)):
            #Get if media item is whitelisted
            item_info=get_additional_item_info(server_url, user_key, item['Id'], auth_key)
            itemIsWhiteListed=get_iswhitelisted(item_info['Path'])
            if (
               (item['Type'] == 'Video') and
               (cfg.not_played_age_video >= 0) and
               (item['UserData']['PlayCount'] >= 1) and
               (cut_off_date_video > parse(item['UserData']['LastPlayedDate'])) and
               (not bool(cfg.keep_favorites_video) or not item['UserData']['IsFavorite']) and
               (not itemIsWhiteListed)
               ):
                try:
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' -  Favorite: ' + str(item['UserData']['IsFavorite']) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'VideoID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Delete Video: \n' + str(item))
                print(':*[DELETE] - ' + item_details)
                deleteItems.append(item)
            else:
                try:
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(item['UserData']['IsFavorite']) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'VideoID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Keep Video: \n' + str(item))
                print(':[KEEPING] - ' + item_details)
        #find trailer media items ready to delete
        elif ((item['Type'] == 'Trailer') and not (cfg.not_played_age_trailer == -1)):
            #Get if media item is whitelisted
            item_info=get_additional_item_info(server_url, user_key, item['Id'], auth_key)
            itemIsWhiteListed=get_iswhitelisted(item_info['Path'])
            if (
               (cfg.not_played_age_trailer >= 0) and
               (item['UserData']['PlayCount'] >= 1) and
               (cut_off_date_trailer > parse(item['UserData']['LastPlayedDate'])) and
               (not bool(cfg.keep_favorites_trailer) or not item['UserData']['IsFavorite']) and
               (not itemIsWhiteListed)
               ):
                try:
                    item_details=' ' + item['Type'] + ' - ' + item['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' -  Favorite: ' + str(item['UserData']['IsFavorite']) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'TrailerID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details=' ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Delete Trailer: \n' + str(item))
                print(':*[DELETE] - ' + item_details)
                deleteItems.append(item)
            else:
                try:
                    item_details=' ' + item['Type'] + ' - ' + item['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(item['UserData']['IsFavorite']) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'TrailerID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details=' ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Keep Trailer: \n' + str(item))
                print(':[KEEPING] - ' + item_details)
        #find audio media items ready to delete
        elif ((item['Type'] == 'Audio') and not (cfg.not_played_age_audio == -1)):
            #Get if track, album, or artist is set as favorite
            itemisfav_MUSICtaa=get_isfav_MUSICtaa(isfav_MUSICtaa, item, server_url, user_key, auth_key)
            #Get if media item is whitelisted
            item_info=get_additional_item_info(server_url, user_key, item['Id'], auth_key)
            itemIsWhiteListed=get_iswhitelisted(item_info['Path'])
            if (
               (cfg.not_played_age_audio >= 0) and
               (item['UserData']['PlayCount'] >= 1) and
               (cut_off_date_audio > parse(item['UserData']['LastPlayedDate'])) and
               (not bool(cfg.keep_favorites_audio) or (not itemisfav_MUSICtaa)) and
               (not itemIsWhiteListed)
               ):
                try:
                    item_details='  ' + item['Type'] + ' - Track: ' + item['Name'] + ' - Album: ' + item['Album'] + ' - Artist: ' + item['Artists'][0] + ' - Record Label: ' + item['Studios'][0]['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_MUSICtaa) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'TrackID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - Track: ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Delete Audio: \n' + str(item))
                print(':*[DELETE] - ' + item_details)
                deleteItems.append(item)
            else:
                try:
                    item_details='  ' + item['Type'] + ' - Track: ' + item['Name'] + ' - Album: ' + item['Album'] + ' - Artist: ' + item['Artists'][0] + ' - Record Label: ' + item['Studios'][0]['Name'] + ' - ' + get_days_since_played(item['UserData']['LastPlayedDate']) + ' - Favorite: ' + str(itemisfav_MUSICtaa) + ' - Whitelisted: ' + str(itemIsWhiteListed) + ' - ' + 'TrackID: ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - Track: ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('\nError encountered - Keep Audio: \n' + str(item))
                print(':[KEEPING] - ' + item_details)
        #idk what these are; keep them
        else: #(item['Type'] == 'Unknown')
            try:
                if bool(cfg.DEBUG):
                    item_details=item['Type'] + ' - ' + item['Name'] + ' - Favorite: ' + str(item['UserData']['IsFavorite']) + ' - ID: ' + item['Id']
            except (KeyError, IndexError):
                if bool(cfg.DEBUG):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    #DEBUG
                    print('\nError encountered - Keep Unknown Media Type: \n' + str(item))
            if bool(cfg.DEBUG):
                print(':[KEEPING] - ' + item_details)

    if len(data['Items']) <= 0:
        print('[NO PLAYED ITEMS]')

    if bool(cfg.DEBUG):
        print('-----------------------------------------------------------')
        print('')
        print('isfav_MOVIE: ')
        print(isfav_MOVIE)
        print('')
        print('isfav_TVessn: ')
        print(isfav_TVessn)
        print('')
        print('isfav_MUSICtaa: ')
        print(isfav_MUSICtaa)
        print('')

    print('-----------------------------------------------------------')
    print('\n')
    return(deleteItems)


#list and delete items past played threshold
def list_delete_items(deleteItems):
    #List items to be deleted
    print('-----------------------------------------------------------')
    print('Summary Of Deleted Media:')
    if not bool(cfg.remove_files):
        print('* Trial Run           *')
        print('* remove_files=0      *')
        print('* No Media Deleted    *')
        print('* Items = ' + str(len(deleteItems)))
        print('-----------------------------------------------------------')
    else:
        print('* Items Deleted = ' + str(len(deleteItems)) + '    *')
        print('-----------------------------------------------------------')

    if len(deleteItems) > 0:
        for item in deleteItems:
            if item['Type'] == 'Movie':
                item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
            elif item['Type'] == 'Episode':
                try:
                    item_details=item['Type'] + ' - ' + item['SeriesName'] + ' - ' + get_season_episode(item['ParentIndexNumber'], item['IndexNumber']) + ' - ' + item['Name'] + ' - ' + item['Id']
                except (KeyError, IndexError):
                    item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
                    if bool(cfg.DEBUG):
                        #DEBUG
                        print('Error encountered - Delete Episode: \n\n' + str(item))
            elif item['Type'] == 'Video':
                item_details='  ' + item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
            elif item['Type'] == 'Trailer':
                item_details=item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
            elif item['Type'] == 'Audio':
                item_details=item['Type'] + ' - ' + item['Name'] + ' - ' + item['Id']
            else: # item['Type'] == 'Unknown':
                pass
            #Delete media item
            delete_item(item['Id'])
            print('[DELETED] ' + item_details)
    else:
        print('[NO ITEMS TO DELETE]')

    print('-----------------------------------------------------------')
    print('\n')
    print('-----------------------------------------------------------')
    print('Done.')
    print('-----------------------------------------------------------')
    print('')


#Check select config variables are an expected value
def cfgCheck():

    errorfound=False
    error_found_in_media_cleaner_config_py=''
    #need to find clean way to put cfg.variable_names in a dict/list/etc... and use the dict/list/etc... to call the varibles by name in a for loop
    test=cfg.not_played_age_movie
    if (
        not ((type(test) is int) and
        (test >= -1) and
        (test <= 365000000))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: not_played_age_movie must be an integer; valid range -1 thru 365000000\n'

    test=cfg.not_played_age_episode
    if (
        not ((type(test) is int) and
        (test >= -1) and
        (test <= 365000000))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: not_played_age_episode must be an integer; valid range -1 thru 365000000\n'

    test=cfg.not_played_age_video
    if (
        not ((type(test) is int) and
        (test >= -1) and
        (test <= 365000000))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: not_played_age_video must be an integer; valid range -1 thru 365000000\n'

    test=cfg.not_played_age_trailer
    if (
        not ((type(test) is int) and
        (test >= -1) and
        (test <= 365000000))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: not_played_age_trailer must be an integer; valid range -1 thru 365000000\n'

    test=cfg.not_played_age_audio
    if (
        not ((type(test) is int) and
        (test >= -1) and
        (test <= 365000000))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: not_played_age_audio must be an integer; valid range -1 thru 365000000\n'

    test=cfg.keep_favorites_movie
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_movie must be an integer; valid values 0 and 1\n'

    test=cfg.keep_favorites_episode
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_episode must be an integer; valid values 0 and 1\n'

    test=cfg.keep_favorites_video
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_video must be an integer; valid values 0 and 1\n'

    test=cfg.keep_favorites_trailer
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_trailer must be an integer; valid values 0 and 1\n'

    test=cfg.keep_favorites_audio
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_audio must be an integer; valid values 0 and 1\n'

    test=cfg.keep_favorites_advanced
    if (
        not ((type(test) is str) and
        (int(test, 2) >= 0) and
        (int(test, 2) <= 255) and
        (len(test) >= 6) and
        (len(test) <= 8))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_advanced should be an 8-digit binary string; valid range binary - 00000000 thru 11111111 (decimal - 0 thru 255)\n'

    test=cfg.keep_favorites_advanced_any
    if (
        not ((type(test) is str) and
        (int(test, 2) >= 0) and
        (int(test, 2) <= 255) and
        (len(test) >= 6) and
        (len(test) <= 8))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: keep_favorites_advanced_any should be an 8-digit binary string; valid range binary - 00000000 thru 11111111 (decimal - 0 thru 255)\n'

    test=cfg.whitelisted_library_folders
    if (
        not (type(test) is str)
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: whitelisted_library_folders must be a string\n'

    test=cfg.remove_files
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: remove_files must be an integer; valid values 0 and 1\n'

    test=cfg.server_brand
    if (
        not (type(test) is str)
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: server_brand must be a string\n'

    test=cfg.server_url
    if (
        not (type(test) is str)
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: server_url must be a string\n'

    test=cfg.admin_username
    if (
        not (type(test) is str)
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: admin_username must be a string\n'

    test=cfg.access_token
    if (
        not ((type(test) is str) and
        (len(test) == 32) and
        (str(test).isalnum()))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: access_token must be a 32-character alphanumeric string\n'

    test=cfg.user_key
    if (
        not ((type(test) is str) and
        (len(test) == 32) and
        (str(test).isalnum()))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: user_key must be a 32-character alphanumeric string\n'

    test=cfg.DEBUG
    if (
        not ((type(test) is int) and
        (test >= 0) and
        (test <= 1))
       ):
        errorfound=True
        error_found_in_media_cleaner_config_py+='TypeError: DEBUG must be an integer; valid values 0 and 1'

    if (errorfound):
        error_found_in_media_cleaner_config_py=error_found_in_media_cleaner_config_py.replace('TypeError: ','',1)
        raise TypeError(error_found_in_media_cleaner_config_py)

############# START OF SCRIPT #############

try:
    #try importing the media_cleaner_config.py file
    #if media_cleaner_config.py file does not exsit go to except and create one
    import media_cleaner_config as cfg
    #try setting DEBUG variable from media_cleaner_config.py file
    #if DEBUG does not exsit go to except and completely rebuild the media_cleaner_config.py file
    test=cfg.DEBUG
    #removing DEBUG from media_cleaner_config.py file is sort of configuration reset

    #depending on what is missing from media_cleaner_config.py file; try to only ask for certain input
    if (
        not hasattr(cfg, 'not_played_age_movie') or
        not hasattr(cfg, 'not_played_age_episode') or
        not hasattr(cfg, 'not_played_age_video') or
        not hasattr(cfg, 'not_played_age_trailer') or
        not hasattr(cfg, 'not_played_age_audio') or
        not hasattr(cfg, 'keep_favorites_movie') or
        not hasattr(cfg, 'keep_favorites_episode') or
        not hasattr(cfg, 'keep_favorites_video') or
        not hasattr(cfg, 'keep_favorites_trailer') or
        not hasattr(cfg, 'keep_favorites_audio') or
        not hasattr(cfg, 'keep_favorites_advanced') or
        not hasattr(cfg, 'keep_favorites_advanced_any') or
        not hasattr(cfg, 'remove_files') or
        not hasattr(cfg, 'whitelisted_library_folders') or
        not hasattr(cfg, 'server_brand') or
        not hasattr(cfg, 'server_url') or
        not hasattr(cfg, 'admin_username') or
        not hasattr(cfg, 'access_token') or
        not hasattr(cfg, 'user_key')
       ):
        if (
            not hasattr(cfg, 'server_brand') or
            not hasattr(cfg, 'server_url') or
            not hasattr(cfg, 'admin_username') or
            not hasattr(cfg, 'access_token') or
            not hasattr(cfg, 'user_key') or
            not hasattr(cfg, 'whitelisted_library_folders')
           ):

            if hasattr(cfg, 'server_brand'):
                delattr(cfg, 'server_brand')
            if hasattr(cfg, 'server_url'):
                delattr(cfg, 'server_url')
            if hasattr(cfg, 'admin_username'):
                delattr(cfg, 'admin_username')
            if hasattr(cfg, 'access_token'):
                delattr(cfg, 'access_token')
            if hasattr(cfg, 'user_key'):
                delattr(cfg, 'user_key')
            if hasattr(cfg, 'whitelisted_library_folders'):
                delattr(cfg, 'whitelisted_library_folders')

            print('-----------------------------------------------------------')
            server_brand=get_brand()

            print('-----------------------------------------------------------')
            server=get_url()
            print('-----------------------------------------------------------')
            port=get_port()
            print('-----------------------------------------------------------')
            server_base=get_base(server_brand)
            if (len(port)):
                server_url=server + ':' + port + '/' + server_base
            else:
                server_url=server + '/' + server_base
            print('-----------------------------------------------------------')

            username=get_admin_username()
            print('-----------------------------------------------------------')
            password=get_admin_password()
            print('-----------------------------------------------------------')

            auth_key=get_auth_key(server_url, username, password)
            user_key=list_users(server_url, auth_key)
            print('-----------------------------------------------------------')

            whitelist=list_library_folders(server_url, auth_key)
            print('-----------------------------------------------------------')

        #warn user the configuration file is not complete
        #the missing varibles are not saved and will need to be manually entered the next time the script is run
        #a new media_cleaner_config.py file will need to be completed or manually updated without duplicates
        print('\n')
        print('-----------------------------------------------------------')
        print('ATTENTION!!!')
        print('Old or incomplete config in use.')
        print('1) Delete media_cleaner_config.py and run this again to create a new config.')
        print('   Or')
        print('2) Delete DEBUG from media_cleaner_config.py and run this again to create a new config.')
        print('-----------------------------------------------------------')
        print('Matching value(s) in media_cleaner_config.py ignored.')
        print('Using the below config value(s) for this run:')
        print('-----------------------------------------------------------')

        if not hasattr(cfg, 'not_played_age_movie'):
            print('not_played_age_movie=-1')
            setattr(cfg, 'not_played_age_movie', -1)
        if not hasattr(cfg, 'not_played_age_episode'):
            print('not_played_age_episode=-1')
            setattr(cfg, 'not_played_age_episode', -1)
        if not hasattr(cfg, 'not_played_age_video'):
            print('not_played_age_video=-1')
            setattr(cfg, 'not_played_age_video', -1)
        if not hasattr(cfg, 'not_played_age_trailer'):
            print('not_played_age_trailer=-1')
            setattr(cfg, 'not_played_age_trailer', -1)
        if not hasattr(cfg, 'not_played_age_audio'):
            print('not_played_age_audio=-1')
            setattr(cfg, 'not_played_age_audio', -1)

        if not hasattr(cfg, 'keep_favorites_movie'):
            print('keep_favorites_movie=1')
            setattr(cfg, 'keep_favorites_movie', 1)
        if not hasattr(cfg, 'keep_favorites_episode'):
            print('keep_favorites_episode=1')
            setattr(cfg, 'keep_favorites_episode', 1)
        if not hasattr(cfg, 'keep_favorites_video'):
            print('keep_favorites_video=1')
            setattr(cfg, 'keep_favorites_video', 1)
        if not hasattr(cfg, 'keep_favorites_trailer'):
            print('keep_favorites_trailer=1')
            setattr(cfg, 'keep_favorites_trailer', 1)
        if not hasattr(cfg, 'keep_favorites_audio'):
            print('keep_favorites_audio=1')
            setattr(cfg, 'keep_favorites_audio', 1)
        if not hasattr(cfg, 'keep_favorites_advanced'):
            print('keep_favorites_advanced=00000001')
            setattr(cfg, 'keep_favorites_advanced', '00000001')
        if not hasattr(cfg, 'keep_favorites_advanced_any'):
            print('keep_favorites_advanced_any=00000000')
            setattr(cfg, 'keep_favorites_advanced_any', '00000000')

        if not hasattr(cfg, 'whitelisted_library_folders'):
            print('whitelisted_library_folders=\'\'')
            setattr(cfg, 'whitelisted_library_folders', '\'\'')

        if not hasattr(cfg, 'remove_files'):
            print('remove_files=0')
            setattr(cfg, 'remove_files', 0)

        if not hasattr(cfg, 'server_brand'):
            print('server_brand=\'' + str(server_brand) + '\'')
            setattr(cfg, 'server_brand', server_brand)
        if not hasattr(cfg, 'server_url'):
            print('server_url=\'' + str(server_url) + '\'')
            setattr(cfg, 'server_url', server_url)
        if not hasattr(cfg, 'admin_username'):
            print('admin_username=\'' + str(username) + '\'')
            setattr(cfg, 'admin_username', username)
        if not hasattr(cfg, 'access_token'):
            print('access_token=\'' + str(auth_key) + '\'')
            setattr(cfg, 'access_token', auth_key)
        if not hasattr(cfg, 'user_key'):
            print('user_key=\'' + str(user_key) + '\'')
            setattr(cfg, 'user_key', user_key)

        #print('DEBUG=' + str(cfg.DEBUG))

        print('-----------------------------------------------------------')
        print ('\n')

#the except
except (AttributeError, ModuleNotFoundError):
    #we are here because the media_cleaner_config.py file does not exist
    #this is either the first time the script is running or media_cleaner_config.py file was deleted
    #when this happens create a new media_cleaner_config.py file
    #another possible reason we are here...
    #the above attempt to set test=cfg.DEBUG failed likely because DEBUG is missing from the media_cleaner_config.py file
    #when this happens create a new media_cleaner_config.py file
    generate_config()
    #exit gracefully
    exit(0)

#check config values are what we expect them to be
cfgCheck()
#find media items to be deleted
deleteItems=get_items(cfg.server_url, cfg.user_key, cfg.access_token)
#list and delete found media items
list_delete_items(deleteItems)

############# END OF SCRIPT #############
