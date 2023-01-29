use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub(crate) struct User {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Id")]
    pub id: String,
}

#[derive(Serialize, Deserialize)]
pub(crate) struct AuthenticatedUser {
    #[serde(rename = "User")]
    pub user: User,
    #[serde(rename = "AccessToken")]
    pub access_token: String,
    #[serde(rename = "ServerId")]
    pub server_id: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct UserData {
    #[serde(rename = "IsFavorite")]
    pub is_favorite: bool,
    #[serde(rename = "Played")]
    pub played: bool,
    #[serde(rename = "LastPlayedDate")]
    pub last_played_date: Option<DateTime<Utc>>,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct Item {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Id")]
    pub id: String,
    #[serde(rename = "CanDelete")]
    pub can_delete: bool,
    #[serde(rename = "Type")]
    pub r#type: String,
    #[serde(rename = "UserData")]
    pub user_data: UserData,
}

#[derive(Serialize, Deserialize)]
pub(crate) struct Items {
    #[serde(rename = "Items")]
    pub items: Vec<Item>,
    #[serde(rename = "TotalRecordCount")]
    pub total_record_count: i64,
}
