mod types;

use crate::types::{AuthenticatedUser, Item, Items};
use chrono::{DateTime, Days, Utc};
use log::{debug, info};
use reqwest::blocking::Client;
use std::env;

fn main() -> Result<(), Error> {
    simple_logger::init_with_env().unwrap();
    let emby_host = env::var("EMBY_HOST").map_err(|_| Error::MissingEmbyHost)?;
    let username = env::var("EMBY_USERNAME").map_err(|_| Error::MissingEmbyUsername)?;
    let pwd = env::var("EMBY_PWD").map_err(|_| Error::MissingEmbyPassword)?;
    let threshold = env::var("DELETE_THRESHOLD_IN_DAYS")
        .map_err(|_| Error::InvalidTimeThreshold)?
        .parse()
        .map_err(|_| Error::InvalidTimeThreshold)?;

    let time_threshold = Utc::now()
        .checked_sub_days(Days::new(threshold))
        .ok_or(Error::InvalidTimeThreshold)?;

    let client = MediaCleaner::new(emby_host, &username, &pwd, time_threshold)?;

    let movies_to_delete = client.fetch_movies_to_delete()?;
    info!("Movies to delete: {:?}", movies_to_delete.len());
    client
        .delete_items(movies_to_delete)
        .map_err(Error::FailedToDeleteMovies)?;

    let episodes_to_delete = client.fetch_episodes_to_delete()?;
    info!("Episodes to delete: {:?}", episodes_to_delete.len());
    client
        .delete_items(episodes_to_delete)
        .map_err(Error::FailedToDeleteTvShows)?;
    Ok(())
}

#[derive(Debug)]
enum Error {
    MissingEmbyUsername,
    MissingEmbyPassword,
    MissingEmbyHost,
    FailedToAuthenticate(reqwest::Error),
    FailedToGetMoviesId,
    FailedToGetMovies(reqwest::Error),
    InvalidTimeThreshold,
    FailedToGetTvShowsId,
    FailedToGetTvShows(reqwest::Error),
    FailedToDeleteMovies(reqwest::Error),
    FailedToDeleteTvShows(reqwest::Error),
}

struct MediaCleaner {
    client: Client,
    base_url: String,
    auth: AuthenticatedUser,
    time_threshold: DateTime<Utc>,
}

impl MediaCleaner {
    pub(crate) fn new(
        mut host: String,
        username: &str,
        pwd: &str,
        time_threshold: DateTime<Utc>,
    ) -> Result<Self, Error> {
        host = host.trim_end_matches('/').to_string();
        let form = vec![("Username", username), ("Pw", pwd)];
        let queries = Self::common_url_queries(None);
        let client = Client::new();
        let auth = client
            .post(format!("{}/emby/Users/authenticatebyname", host))
            .query(&queries)
            .form(&form)
            .send()
            .map_err(Error::FailedToAuthenticate)?
            .json::<AuthenticatedUser>()
            .map_err(Error::FailedToAuthenticate)?;

        Ok(Self {
            client,
            base_url: host,
            auth,
            time_threshold,
        })
    }

    fn fetch_movies_to_delete(&self) -> Result<Vec<Item>, Error> {
        let top_items = self
            .fetch_items(None, None)
            .map_err(Error::FailedToGetMovies)?;
        let movies_parent_id = top_items
            .iter()
            .find(|item| item.name == "Movies")
            .map(|item| item.id.to_string())
            .ok_or(Error::FailedToGetMoviesId)?;

        debug!("Found Movies parentId: {}", movies_parent_id);

        let collections_parent_id = top_items
            .iter()
            .find(|item| item.name == "Collections")
            .map(|item| item.id.to_string())
            .ok_or(Error::FailedToGetMoviesId)?;

        debug!("Found Collections parentId: {}", collections_parent_id);

        let fav_collection_movies = self
            .fetch_items(Some(&collections_parent_id), None)
            .map_err(Error::FailedToGetMovies)?
            .into_iter()
            .filter(|item| item.user_data.is_favorite)
            .flat_map(|item| {
                debug!("Fetching favourite Boxset: {}", item.name);
                self.fetch_items(Some(&item.id), Some("Movie"))
                    .map_err(Error::FailedToGetMovies)
            })
            .flatten()
            .map(|item| item.id)
            .collect::<Vec<String>>();

        debug!("Filtering favourite Movies...");
        let movies = self
            .fetch_items(Some(&movies_parent_id), Some("Movie"))
            .map_err(Error::FailedToGetMovies)?
            .into_iter()
            .filter(|item| {
                item.can_delete
                    && item.user_data.played
                    && !item.user_data.is_favorite
                    && item.user_data.last_played_date.is_some()
                    && !fav_collection_movies.contains(&item.id)
            })
            .filter(|item| {
                if let Some(watched_time) = item.user_data.last_played_date {
                    let res = watched_time.le(&self.time_threshold);
                    if res {
                        debug!("Movie marked for delete: {}", item.name);
                    }
                    res
                } else {
                    false
                }
            })
            .collect();

        Ok(movies)
    }

    fn fetch_episodes_to_delete(&self) -> Result<Vec<Item>, Error> {
        let top_items = self
            .fetch_items(None, None)
            .map_err(Error::FailedToGetTvShows)?;
        let series_parent_id = top_items
            .iter()
            .find(|item| item.name == "TV shows")
            .map(|item| item.id.to_string())
            .ok_or(Error::FailedToGetTvShowsId)?;

        debug!("Found TV Shows parentId: {}", series_parent_id);

        let episodes = self
            .fetch_items(Some(&series_parent_id), Some("Series"))
            .map_err(Error::FailedToGetTvShows)?
            .into_iter()
            // filter series
            .filter_map(|item| {
                debug!("Checking TV Show: {}", item.name);
                if item.can_delete && !item.user_data.is_favorite {
                    self.fetch_items(Some(&item.id), Some("Season"))
                        .map(|seasons| (item.name, seasons))
                        .ok()
                } else {
                    None
                }
            })
            // filter seasons
            .flat_map(|(series, seasons)| {
                let values: Vec<(String, String, Vec<Item>)> = seasons
                    .into_iter()
                    .filter_map(|season| {
                        debug!("Checking TV Show {}: {}", series, season.name);
                        if season.can_delete && !season.user_data.is_favorite {
                            self.fetch_items(Some(&season.id), Some("Episode"))
                                .map(|items| (series.clone(), season.name, items))
                                .ok()
                        } else {
                            None
                        }
                    })
                    .collect();
                values
            })
            // filter episodes
            .flat_map(|(series, season, episodes)| {
                episodes
                    .into_iter()
                    .filter_map(|mut episode| {
                        if episode.can_delete
                            && episode.user_data.played
                            && !episode.user_data.is_favorite
                        {
                            if let Some(watched_time) = episode.user_data.last_played_date {
                                if watched_time.le(&self.time_threshold) {
                                    let name =
                                        format!("{} - {} - {}", series, season, episode.name);
                                    debug!("Deleting: {name}",);
                                    episode.name = name;
                                    return Some(episode);
                                }
                            }
                        }

                        None
                    })
                    .collect::<Vec<Item>>()
            })
            .collect();

        Ok(episodes)
    }

    fn delete_items(&self, items: Vec<Item>) -> Result<(), reqwest::Error> {
        for item in items {
            info!("Deleting {:?}", item.name);
            self.client
                .post(format!("{}/emby/Items/{}/Delete", self.base_url, item.id))
                .query(&Self::common_url_queries(Some(&self.auth.access_token)))
                .send()?;
        }
        Ok(())
    }

    fn fetch_items(
        &self,
        maybe_parent_id: Option<&str>,
        include_item_types: Option<&str>,
    ) -> Result<Vec<Item>, reqwest::Error> {
        let mut queries = Self::common_url_queries(Some(&self.auth.access_token));
        queries.push(("Fields", "BasicSyncInfo,CanDelete"));
        queries.push(("StartIndex", "0"));

        if let Some(include_item_type) = include_item_types {
            queries.push(("IncludeItemTypes", include_item_type));
        }

        if let Some(parent_id) = maybe_parent_id {
            queries.push(("Parentid", parent_id));
        }

        let items = self
            .client
            .get(format!(
                "{}/emby/Users/{}/Items",
                self.base_url, self.auth.user.id
            ))
            .query(&queries)
            .send()?
            .json::<Items>()?;

        Ok(items.items)
    }

    fn common_url_queries(maybe_token: Option<&str>) -> Vec<(&str, &str)> {
        let mut queries = vec![
            ("X-Emby-Client", "API"),
            ("X-Emby-Device-Name", "Media Cleaner"),
            ("X-Emby-Device-Id", "fe11a56d-b049-4eff-a25a-b87243e642dd"),
            ("X-Emby-Client-Version", "1.0"),
        ];

        if let Some(token) = maybe_token {
            queries.push(("X-Emby-Token", token));
        }

        queries
    }
}
