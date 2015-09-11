-- MySQL Script generated by MySQL Workbench
-- Fri Sep 11 16:49:00 2015
-- Model: New Model    Version: 1.0
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
-- -----------------------------------------------------
-- Schema drugdb
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `drugdb` DEFAULT CHARACTER SET utf8 ;
USE `drugdb` ;

-- -----------------------------------------------------
-- Table `drugdb`.`Name_of_set_if_isogenic`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Name_of_set_if_isogenic` (
  `Name_of_set_if_isogenic_ID` INT NOT NULL AUTO_INCREMENT,
  `Name_of_set_if_isogenic` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`Name_of_set_if_isogenic_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Instrument_used`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Instrument_used` (
  `Instrument_used_ID` INT NOT NULL AUTO_INCREMENT,
  `Instrument_name` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`Instrument_used_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Tissue_type`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Tissue_type` (
  `Tissue_type_ID` INT NOT NULL AUTO_INCREMENT,
  `Tissue_of_origin` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`Tissue_type_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Cell_line`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Cell_line` (
  `Cell_line_ID` INT NOT NULL AUTO_INCREMENT,
  `Cell_line_name` VARCHAR(45) NULL DEFAULT NULL,
  `Tissue_type_Tissue_type_ID` INT NULL DEFAULT NULL,
  PRIMARY KEY (`Cell_line_ID`),
  INDEX `fk_Cell_line_Tissue_type1` (`Tissue_type_Tissue_type_ID` ASC),
  CONSTRAINT `fk_Cell_line_Tissue_type1`
    FOREIGN KEY (`Tissue_type_Tissue_type_ID`)
    REFERENCES `drugdb`.`Tissue_type` (`Tissue_type_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Transfection_reagent_used`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Transfection_reagent_used` (
  `Transfection_reagent_used_ID` INT NOT NULL AUTO_INCREMENT,
  `Transfection_reagent` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`Transfection_reagent_used_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Compound_library`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Compound_library` (
  `Compound_library_ID` INT NOT NULL AUTO_INCREMENT,
  `Compound_library_name` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`Compound_library_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Plateconf_file_path`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Plateconf_file_path` (
  `Plateconf_file_path_ID` INT NOT NULL AUTO_INCREMENT,
  `Plateconf_file_location` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`Plateconf_file_path_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Platelist_file_path`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Platelist_file_path` (
  `Platelist_file_path_ID` INT NOT NULL AUTO_INCREMENT,
  `Platelist_file_location` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`Platelist_file_path_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Compound_library_file`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Compound_library_file` (
  `Compound_library_file_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_complib` VARCHAR(10) NULL DEFAULT NULL,
  `Well_complib` VARCHAR(10) NULL DEFAULT NULL,
  `Compound` VARCHAR(20) NULL DEFAULT NULL,
  `Function` VARCHAR(20) NULL DEFAULT NULL,
  `CAS` VARCHAR(10) NULL DEFAULT NULL,
  `Layout` VARCHAR(45) NULL,
  `Concentration_pM` VARCHAR(45) NULL,
  `Compound_library_Compound_library_ID` INT NULL,
  PRIMARY KEY (`Compound_library_file_ID`),
  INDEX `col_Sub_lib1_idx` (`CAS` ASC),
  INDEX `col_Gene_symbol_templib1_idx` (`Compound` ASC),
  INDEX `fk_Compound_library_file_Compound_library1_idx` (`Compound_library_Compound_library_ID` ASC),
  CONSTRAINT `fk_Compound_library_file_Compound_library1`
    FOREIGN KEY (`Compound_library_Compound_library_ID`)
    REFERENCES `drugdb`.`Compound_library` (`Compound_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Drug_screen_info`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Drug_screen_info` (
  `Drug_screen_info_ID` INT NOT NULL AUTO_INCREMENT,
  `Cell_line` VARCHAR(45) NULL,
  `Drug_screen_name` VARCHAR(100) NULL DEFAULT NULL,
  `Date_of_run` VARCHAR(45) NULL DEFAULT NULL,
  `Operator` VARCHAR(45) NULL DEFAULT NULL,
  `Is_isogenic` VARCHAR(45) NULL DEFAULT NULL,
  `Gene_name_if_isogenic` VARCHAR(45) NULL DEFAULT NULL,
  `Isogenic_mutant_description` VARCHAR(45) NULL DEFAULT NULL,
  `Method_of_isogenic_knockdown` VARCHAR(45) NULL DEFAULT NULL,
  `Compound` VARCHAR(100) NULL DEFAULT NULL,
  `Compound_concentration` VARCHAR(45) NULL DEFAULT NULL,
  `Dosing_regime` VARCHAR(45) NULL DEFAULT NULL,
  `Compound_library_name` VARCHAR(45) NULL DEFAULT NULL,
  `Plate_list_file_name` VARCHAR(45) NULL DEFAULT NULL,
  `Plate_conf_file_name` VARCHAR(45) NULL DEFAULT NULL,
  `Drug_screen_link_to_report` VARCHAR(500) NULL DEFAULT NULL,
  `Drug_screen_link_to_qc_plots` VARCHAR(500) NULL DEFAULT NULL,
  `Zprime` VARCHAR(45) NULL DEFAULT NULL,
  `Summary_file_path` VARCHAR(500) NULL DEFAULT NULL,
  `Notes` VARCHAR(1000) NULL DEFAULT NULL,
  `Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID` INT NULL DEFAULT NULL,
  `Instrument_used_Instrument_used_ID` INT NULL DEFAULT NULL,
  `Tissue_type_Tissue_type_ID` INT NULL DEFAULT NULL,
  `Transfection_reagent_used_Transfection_reagent_used_ID` INT NULL DEFAULT NULL,
  `Plateconf_file_path_Plateconf_file_path_ID` INT NULL DEFAULT NULL,
  `Platelist_file_path_Platelist_file_path_ID` INT NULL DEFAULT NULL,
  `Compound_library_Compound_library_ID` INT NULL,
  PRIMARY KEY (`Drug_screen_info_ID`),
  INDEX `fk_Rnai_screen_info_Name_of_set_if_isogenic1_idx` (`Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID` ASC),
  INDEX `fk_Rnai_screen_info_Instrument_used1_idx` (`Instrument_used_Instrument_used_ID` ASC),
  INDEX `fk_Rnai_screen_info_Tissue_type1_idx` (`Tissue_type_Tissue_type_ID` ASC),
  INDEX `fk_Rnai_screen_info_Transfection_reagent_used1_idx` (`Transfection_reagent_used_Transfection_reagent_used_ID` ASC),
  INDEX `fk_Rnai_screen_info_Plateconf_file_path1_idx` (`Plateconf_file_path_Plateconf_file_path_ID` ASC),
  INDEX `fk_Rnai_screen_info_Platelist_file_path1_idx` (`Platelist_file_path_Platelist_file_path_ID` ASC),
  INDEX `col_Cell_line1_idx` (`Cell_line` ASC),
  INDEX `fk_Drug_screen_info_Compound_library1_idx` (`Compound_library_Compound_library_ID` ASC),
  CONSTRAINT `fk_Rnai_screen_info_Name_of_set_if_isogenic1`
    FOREIGN KEY (`Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID`)
    REFERENCES `drugdb`.`Name_of_set_if_isogenic` (`Name_of_set_if_isogenic_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Instrument_used1`
    FOREIGN KEY (`Instrument_used_Instrument_used_ID`)
    REFERENCES `drugdb`.`Instrument_used` (`Instrument_used_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Tissue_type1`
    FOREIGN KEY (`Tissue_type_Tissue_type_ID`)
    REFERENCES `drugdb`.`Tissue_type` (`Tissue_type_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Transfection_reagent_used1`
    FOREIGN KEY (`Transfection_reagent_used_Transfection_reagent_used_ID`)
    REFERENCES `drugdb`.`Transfection_reagent_used` (`Transfection_reagent_used_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Plateconf_file_path1`
    FOREIGN KEY (`Plateconf_file_path_Plateconf_file_path_ID`)
    REFERENCES `drugdb`.`Plateconf_file_path` (`Plateconf_file_path_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Rnai_screen_info_Platelist_file_path1`
    FOREIGN KEY (`Platelist_file_path_Platelist_file_path_ID`)
    REFERENCES `drugdb`.`Platelist_file_path` (`Platelist_file_path_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Drug_screen_info_Compound_library1`
    FOREIGN KEY (`Compound_library_Compound_library_ID`)
    REFERENCES `drugdb`.`Compound_library` (`Compound_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Plate_excel_file_as_text`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Plate_excel_file_as_text` (
  `Plate_excel_file_as_text_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_number_xls_file` VARCHAR(3) NULL DEFAULT NULL,
  `Well_number_xls_file` VARCHAR(11) NULL DEFAULT NULL,
  `Raw_score_xls_file` INT(11) NULL DEFAULT NULL,
  `Drug_screen_info_Drug_screen_info_ID` INT NULL,
  PRIMARY KEY (`Plate_excel_file_as_text_ID`),
  INDEX `fk_Plate_excel_file_as_text_Drug_screen_info1_idx` (`Drug_screen_info_Drug_screen_info_ID` ASC),
  CONSTRAINT `fk_Plate_excel_file_as_text_Drug_screen_info1`
    FOREIGN KEY (`Drug_screen_info_Drug_screen_info_ID`)
    REFERENCES `drugdb`.`Drug_screen_info` (`Drug_screen_info_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Summary_of_result`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Summary_of_result` (
  `Summary_of_result_ID` INT NOT NULL AUTO_INCREMENT,
  `Plate_number_for_summary` VARCHAR(3) NULL DEFAULT NULL,
  `Position` VARCHAR(45) NULL DEFAULT NULL,
  `Zscore_summary` VARCHAR(45) NULL DEFAULT NULL,
  `Well_number_for_summary` VARCHAR(11) NULL DEFAULT NULL,
  `Well_anno` VARCHAR(45) NULL DEFAULT NULL,
  `Final_well_anno` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_r1_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_r2_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_r3_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Median_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Average_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_plate_median_r1_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_plate_median_r2_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Raw_plate_median_r3_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Normalized_r1_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Normalized_r2_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Normalized_r3_ch1` VARCHAR(45) NULL DEFAULT NULL,
  `Gene_symbol_summary` VARCHAR(45) NULL DEFAULT NULL,
  `Entrez_gene_id_summary` VARCHAR(45) NULL DEFAULT NULL,
  `Compound_library_Compound_library_ID` INT NULL,
  PRIMARY KEY (`Summary_of_result_ID`),
  INDEX `col_Zscore_summary1_idx` (`Zscore_summary` ASC),
  INDEX `fk_Summary_of_result_Compound_library1_idx` (`Compound_library_Compound_library_ID` ASC),
  CONSTRAINT `fk_Summary_of_result_Compound_library1`
    FOREIGN KEY (`Compound_library_Compound_library_ID`)
    REFERENCES `drugdb`.`Compound_library` (`Compound_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`User_info`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`User_info` (
  `User_info_ID` INT NOT NULL AUTO_INCREMENT,
  `Username` VARCHAR(50) NULL DEFAULT NULL,
  `Password` VARCHAR(100) NULL DEFAULT NULL,
  PRIMARY KEY (`User_info_ID`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `drugdb`.`Doseresponse_result`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `drugdb`.`Doseresponse_result` (
  `Doseresponse_result_ID` INT NOT NULL AUTO_INCREMENT,
  `Drug` VARCHAR(45) NULL,
  `Layout` VARCHAR(45) NULL,
  `SF80` VARCHAR(45) NULL,
  `SF50` VARCHAR(45) NULL,
  `SF20` VARCHAR(45) NULL,
  `AUC100` VARCHAR(45) NULL,
  `Slope` VARCHAR(45) NULL,
  `Slope_pval` VARCHAR(45) NULL,
  `Einf` VARCHAR(45) NULL,
  `EC50` VARCHAR(45) NULL,
  `LOF_pval` VARCHAR(45) NULL,
  `AUC100_actual` VARCHAR(45) NULL,
  `Compound_library_Compound_library_ID` INT NULL,
  PRIMARY KEY (`Doseresponse_result_ID`),
  INDEX `fk_Doseresponse_result_Compound_library1_idx` (`Compound_library_Compound_library_ID` ASC),
  CONSTRAINT `fk_Doseresponse_result_Compound_library1`
    FOREIGN KEY (`Compound_library_Compound_library_ID`)
    REFERENCES `drugdb`.`Compound_library` (`Compound_library_ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
