/*
  Warnings:

  - A unique constraint covering the columns `[user_id,journal_id]` on the table `bookmarks` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[user_id,location_id]` on the table `user_stamps` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `journals` ADD COLUMN `report_count` INTEGER NOT NULL DEFAULT 0,
    MODIFY `status` ENUM('DRAFT', 'PUBLISHED', 'PRIVATE_ARCHIVE', 'BLOCKED') NOT NULL DEFAULT 'DRAFT';

-- AlterTable
ALTER TABLE `users` ADD COLUMN `profile_photo_url` VARCHAR(500) NULL;

-- CreateIndex
CREATE UNIQUE INDEX `bookmarks_user_id_journal_id_key` ON `bookmarks`(`user_id`, `journal_id`);

-- CreateIndex
CREATE UNIQUE INDEX `user_stamps_user_id_location_id_key` ON `user_stamps`(`user_id`, `location_id`);
