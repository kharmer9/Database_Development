if not exists(select * from sys.databases where name='music')
    create database music
GO

use music
go

-- DOWN
-- ratings table
if exists(select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_ratings_rating_song_id')
    alter table ratings drop constraint fk_ratings_rating_song_id
if exists(select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_ratings_rating_by_user')
    alter table ratings drop constraint fk_ratings_rating_by_user
drop table if exists ratings

-- songs table
if exists(select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_songs_song_album_id')
    alter table songs drop constraint fk_songs_song_album_id
if exists(select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_songs_song_genre_id')
    alter table songs drop constraint fk_songs_song_genre_id
drop table if exists songs

-- users table
drop table if exists users

-- albums table
if exists(select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    where CONSTRAINT_NAME='fk_albums_album_artist_id')
    alter table albums drop constraint fk_albums_album_artist_id
drop table if exists albums

-- genres table
drop table if exists genres

-- artists table
drop table if exists artists

-- UP Metadata
-- artists table
create table artists(
    artist_id int identity not null,
    artist_name varchar(50) not null, -- unique and not multivalued; may be band with no first/last name
    constraint pk_artists_artist_id primary key (artist_id),
    constraint u_artists_artist_name unique (artist_name)
)

-- genres table
create table genres(
    genre_id int identity not null,
    genre varchar(20) not null,
    constraint pk_genres_genre_id primary key(genre_id),
    constraint u_genres_genre unique (genre) -- genres must be unique
)

-- albums table
create table albums(
    album_id int identity not null,
    album_name varchar(50) not null, -- different artists can have same album names; no unique constraint needed
    album_artist_id int not null, -- foreign key to artist table
    constraint pk_albums_album_id primary key (album_id)
)
alter table albums
    add constraint fk_albums_album_artist_id foreign key (album_artist_id)
    references artists(artist_id)

-- users table
create table users(
    user_id int identity not null,
    username varchar(20) not null,
    user_firstname varchar(20) not null,
    user_lastname varchar(20) not null,
    user_email varchar(50) not null,
    user_city varchar(20) not null,
    user_state varchar(2) not null,
    constraint pk_users_user_id primary key(user_id),
    constraint u_users_user_email unique(user_email),
    constraint u_users_username unique(username)
)
-- songs table
create table songs(
    song_id int identity not null,
    song_name varchar(50) not null, -- titles limited to 50 characters
    song_duration_s int not null, -- not sure if time is right
    song_album_id int not null, -- foreign key to album table
    song_genre_id int not null, -- foreign key to genre table
    constraint pk_songs_song_id primary key(song_id)
)
alter table songs
    add constraint fk_songs_song_genre_id foreign key (song_genre_id)
    references genres(genre_id)
alter table songs
    add constraint fk_songs_song_album_id foreign key (song_album_id)
    references albums(album_id)

-- ratings table
create table ratings(
    rating_song_id int not null, -- foreign key to song table
    rating int not null, -- can be decimal if want better analysis
    rating_by_user int not null, -- foreign key to user table
    rating_datetime smalldatetime not null default current_timestamp,
    constraint pk_ratings_by_user_on_song primary key (rating_song_id, rating_by_user),
    constraint ck_ratings_min_max_rating check (rating >= 1 and rating <= 5) -- ratings are between 1 and 5
)
alter table ratings
    add constraint fk_ratings_rating_by_user foreign key (rating_by_user)
    references users(user_id)
alter table ratings
    add constraint fk_ratings_rating_song_id foreign key (rating_song_id)
    references songs(song_id)

-- Derived Columns

-- count of ratings & avg ratings for songs
drop function if exists CountSongRatings
go
CREATE FUNCTION dbo.CountSongRatings (@SongID INT)
RETURNS INT 
AS BEGIN
    DECLARE @RatingCount INT
    SELECT @RatingCount = COUNT(*) FROM ratings WHERE rating_song_id = @SongID
    RETURN @RatingCount
END
go

ALTER TABLE songs
ADD song_num_ratings AS dbo.CountSongRatings(song_id) 

Drop function if exists AvgSongRating
go
CREATE FUNCTION dbo.AvgSongRating (@SongID INT)
RETURNS dec(4,3)
AS BEGIN
    DECLARE @AvgRating dec(4,3)
    SELECT @AvgRating = avg(cast(rating as decimal(4,3))) FROM ratings WHERE rating_song_id = @SongID
    RETURN @AvgRating
END
go

ALTER TABLE songs
ADD song_rating AS dbo.AvgSongRating(song_id)

-- count of songs and avg song rating for albums and genres

drop function if exists CountSongs
go
CREATE FUNCTION dbo.CountSongs (@AlbumID INT)
RETURNS INT 
AS BEGIN
    DECLARE @SongCount INT
    SELECT @SongCount = COUNT(*) FROM songs WHERE song_album_id = @AlbumID
    RETURN @SongCount
END
go

ALTER TABLE albums
ADD album_num_songs AS dbo.CountSongs(album_id) 

ALTER TABLE genres
ADD genre_num_songs AS dbo.CountSongs(genre_id) 

drop function if exists AlbumRating
go
CREATE FUNCTION dbo.AlbumRating (@AlbumID INT)
RETURNS dec(4,3)
AS BEGIN
    DECLARE @AvgRating dec(4,3)
    SELECT @AvgRating = avg(song_rating) FROM songs WHERE song_album_id = @AlbumID
    RETURN @AvgRating
END
go

ALTER TABLE albums
ADD album_rating AS dbo.AlbumRating(album_id)

ALTER TABLE genres
ADD genre_rating as dbo.AlbumRating(genre_id)

-- number of albums and avg album rating for artists

drop function if exists CountAlbums
go
CREATE FUNCTION dbo.CountAlbums (@ArtistID INT)
RETURNS int
AS BEGIN
    DECLARE @AlbumCount int
    SELECT @AlbumCount = COUNT(*) FROM albums WHERE album_artist_id = @ArtistID
    RETURN @AlbumCount
END
go

ALTER TABLE artists
ADD artist_num_albums AS dbo.CountAlbums(artist_id) 

drop function if exists ArtistRating
go
CREATE FUNCTION dbo.ArtistRating (@ArtistID INT)
RETURNS dec(4,3) 
AS BEGIN
    DECLARE @AvgRating dec(4,3)
    SELECT @AvgRating = avg(album_rating) FROM albums WHERE album_artist_id = @ArtistID
    RETURN @AvgRating
END
go

ALTER TABLE artists
ADD artist_rating AS dbo.ArtistRating(artist_id)

-- number of ratings and avg rating for users

drop function if exists CountUserRatings
go
CREATE FUNCTION dbo.CountUserRatings (@UserID INT)
RETURNS INT 
AS BEGIN
    DECLARE @RatingCount INT
    SELECT @RatingCount = COUNT(*) FROM ratings WHERE rating_by_user = @UserID
    RETURN @RatingCount
END
go

ALTER TABLE users
ADD user_num_ratings AS dbo.CountUserRatings(user_id) 

Drop function if exists UserAvgRating
go
CREATE FUNCTION dbo.UserAvgRating (@UserID INT)
RETURNS dec(4,3)
AS BEGIN
    DECLARE @AvgRating dec(4,3)
    SELECT @AvgRating = avg(cast(rating as decimal(4,3))) FROM ratings WHERE rating_by_user = @UserID
    RETURN @avgRating
END
go

ALTER TABLE users
ADD user_avg_rating AS dbo.UserAvgRating(user_id)

-- UP Data

insert into artists -- may add, but do not reorder; fill mess up foreign key
    (artist_name)
    values 
    ('Two Door Cinema Club'),
    ('Mac Demarco'),
    ('Drake'),
    ('Billy Joel'),
    ('Taylor Swift'),
    ('Luke Combs'),
    ('Jordan Davis'),
    ('Avicii'),
    ('Bruno Mars'),
    ('Ed Sheeran'),
    ('Green Day'),
    ('Kayne West'),
    ('Queen'),
    ('Coldplay')

insert into genres -- may add but do not reorder; will mess up foreign key
    (genre)
    values 
    ('Pop'),
    ('Rock'),
    ('Country'),
    ('Hip-Hop/Rap'),
    ('Dance/Electronic'),
    ('Latin'),
    ('Alternative')

insert into albums
    (album_name, album_artist_id)
    values 
    ('Tourist History', 1),
    ('2', 2),
    ('Certified Lover Boy',3),
    ('Scorpion', 3),
    ('An Innocent Man', 4),
    ('Glass Houses', 4),
    ('52nd Street', 4),
    ('The Stranger', 4),
    ('Fearless', 5),
    ('Red', 5),
    ('1989', 5),
    ('This One''s for You Too', 6),
    ('Home State', 7),
    ('Buy Dirt', 7),
    ('True', 8),
    ('Doo-Wops & Hooligans', 9),
    ('Unorthodox Jukebox', 9),
    ('24K Magic', 9),
    ('Divide', 10),
    ('American Idiot', 11),
    ('My Beautiful Dark Twisted Fantasy', 12),
    ('Donda', 12),
    ('The Game', 13),
    ('A Night at the Opera', 13),
    ('A Rush of Blood to the Head', 14)

insert into users 
    (username, user_firstname, user_lastname, user_email, user_city, user_state) 
    values
    ('eamong_musicman', 'Eamon', 'Gallagher', 'etgallag@syr.edu', 'Syracuse', 'NY'),
    ('joey_beats',  'Joseph', 'Baloney', 'joeyb@mail.org', 'New York City', 'NY'),
    ('notKanyeWest', 'Kayne', 'East', 'kwest@rap.org', 'Los Angeles', 'CA'),
    ('jgyl', 'Jake', 'Gyllenhaal','jgyl@hollywood.com', 'Los Angeles', 'CA'),
    ('rapsfacts', 'Aubrey', 'Graham', 'drake@rap.org', 'Toronto', 'ON')

insert into songs -- may add but do not reorder; ratings based on ordered song id
    (song_name, song_duration_s, song_album_id, song_genre_id)
    values 
    ('I Can Talk', 177, 1, 1),
    ('Freaking Out the Neighborhood', 173, 2, 2),
    ('Fair Trade', 291, 3, 4),
    ('God''s Plan', 198, 4, 4),
    ('The Longest Time', 220, 5, 2),
    ('Uptown Girl', 198, 5, 2),
    ('You May Be Right', 255, 6, 2),
    ('My Life', 230, 7, 2),
    ('Vienna', 214, 8, 2),
    ('Love Story', 234, 9, 1),
    ('You Belong With Me', 231, 9, 1),
    ('All Too Well (10 minute version)', 613, 10, 1),
    ('All Too Well', 329, 10, 1),
    ('I Knew You Were Trouble', 219, 10, 1),
    ('We Are Never Getting Back Together', 193, 10, 1),
    ('Shake It Off', 219, 11, 1),
    ('Honky Tonk Highway', 213, 12, 3),
    ('Beautiful Crazy', 193, 12, 3),
    ('Slow Dance in a Parking Lot', 193, 13, 3),
    ('Buy Dirt', 167, 14, 3),
    ('Wake Me Up', 249, 15, 5),
    ('Grenade', 222, 16, 1),
    ('Just The Way You Are', 221, 16, 1),
    ('When I Was Your Man', 214, 17, 1),
    ('24K Magic', 226, 18, 1),
    ('That''s What I Like', 206, 18, 1),
    ('Castle on the Hill', 261, 19, 1),
    ('Shape of You', 233, 19, 1),
    ('Holiday', 232, 20, 2),
    ('Boulevard of Broken Dreams', 260, 20, 2),
    ('Runaway', 339, 21, 4),
    ('Power', 292, 21, 4),
    ('Off the Grid', 339, 22, 4),
    ('Crazy Little Thing Called Love', 162, 23, 2),
    ('Another One Bites the Dust', 215, 23, 2),
    ('Bohemian Rhapsody', 355, 24, 2),
    ('The Scientist', 266, 25, 7),
    ('Clocks', 250, 25, 7)

insert into ratings
    (rating_song_id, rating, rating_by_user)
    values 
    (1, 3, 1),
    (1, 2, 2),
    (2, 5, 1),
    (12, 1, 4),
    (13, 1, 4),
    (3, 1, 3),
    (4, 1, 3),
    (31, 5, 3),
    (32, 5, 3),
    (33, 5, 3),
    (3, 4, 5),
    (4, 5, 5),
    (31, 3, 5),
    (32, 3, 5),
    (33, 2, 5)


 
-- Verfify
/*select * from artists order by artist_id
select * from genres order by genre_id
select * from albums order by album_id
select * from songs order by song_id
select * from users order by user_id
select * from ratings order by rating_datetime desc*/

-- Data Questions
-- 1: Music Recommendations
-- album view with artists
drop view if exists album_artists
go
create view album_artists as (
    select al.album_id, al.album_name, al.album_num_songs, al.album_rating, ar.artist_name
        from albums al
        left join artists ar on al.album_artist_id = ar.artist_id
)
go
select * from album_artists
-- song view with albums, artists and genres
drop view if exists song_album_artist_genre
go
create view song_album_artist_genre as (
    select s.song_id, s.song_name, s.song_duration_s, s.song_num_ratings, s.song_rating, aa.album_name, aa.artist_name, g.genre
        from songs s
            left join album_artists aa on s.song_album_id = aa.album_id
            left join genres g on s.song_genre_id = g.genre_id
)
go
select * from song_album_artist_genre -- song comparison with all relevant information
select * from album_artists -- album comparison with all relevant informaiton
select * from artists -- artist comparison
select * from genres -- genre comparison

-- 2: User opinions
-- specific ratings
drop view if exists user_ratings
go
create view user_ratings as
    (select u.user_id, u.username, u.user_num_ratings, u.user_avg_rating, rating_song_id, rating
        from users u
            left join ratings r on u.user_id = r.rating_by_user)
go
-- specific ratings on songs
drop view if exists user_rating_songs
go
create view user_rating_songs as (
    select ur.user_id, ur.username, ur.rating, s.song_name, ur.user_num_ratings, ur.user_avg_rating
        from user_ratings ur
            left join songs s on ur.rating_song_id = s.song_id
)
go
select * from user_rating_songs

-- 3: Artist Feedback; example = Kayne West
select * from song_album_artist_genre where artist_name = 'Kayne West'
-- or by album
select * from album_artists where artist_name = 'Kayne West'

-- 4: Evaluating Artists; example = comparing Drake and Kayne West
select * from artists where artist_name = 'Drake' or artist_name = 'Kayne West'

-- 5: Genre Comparison; example = Country, Rock, Pop
select * from genres where genre = 'Pop' or genre = 'Country' or genre = 'Rock'