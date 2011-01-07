DROP DATABASE `hypnoscholar`;
CREATE DATABASE IF NOT EXISTS `hypnoscholar`;
GRANT ALL ON hypnoscholar.* TO hypnoscholar@localhost IDENTIFIED BY "st4lkyp0war";
USE `hypnoscholar`;

CREATE TABLE IF NOT EXISTS `tweets` (
	`tweet_id` INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`original_id` BIGINT UNSIGNED NOT NULL UNIQUE,
	`user_screen_name` VARCHAR(255) NOT NULL,
	`text` VARCHAR(255) NOT NULL,
	`in_reply_to_screen_name` VARCHAR(255),
	`in_reply_to_status_id` BIGINT UNSIGNED,
	`source` VARCHAR(255) NOT NULL,
	`posted_at` DATETIME NOT NULL,
	`processed` BOOLEAN NOT NULL DEFAULT FALSE -- Has this been responded to if necessary?
) ENGINE=INNODB;

CREATE TABLE IF NOT EXISTS `messages` (
	`message_id` INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`original_id` BIGINT UNSIGNED NOT NULL UNIQUE,
	`text` VARCHAR(255) NOT NULL,
	`sender_name` BIGINT UNSIGNED NOT NULL,
	`recipient_name` BIGINT UNSIGNED NOT NULL,
	`posted_at` DATETIME NOT NULL,
	`processed` BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=INNOBD;
