-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Creato il: Giu 07, 2023 alle 11:26
-- Versione del server: 10.4.27-MariaDB
-- Versione PHP: 8.2.0

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `aziendadb`
--

-- --------------------------------------------------------

--
-- Struttura della tabella `access_administration`
--

CREATE TABLE `access_administration` (
  `code` int(11) NOT NULL,
  `cusID` varchar(30) DEFAULT NULL,
  `userID` varchar(30) DEFAULT NULL,
  `department` varchar(30) DEFAULT NULL,
  `role` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struttura della tabella `access_table`
--

CREATE TABLE `access_table` (
  `code` int(11) NOT NULL,
  `cusID` varchar(30) DEFAULT NULL,
  `userID` varchar(30) DEFAULT NULL,
  `department` varchar(30) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `finish_date` date DEFAULT NULL,
  `token_1` int(50) DEFAULT NULL,
  `token_2` int(50) DEFAULT NULL,
  `PIN` int(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struttura della tabella `customer`
--

CREATE TABLE `customer` (
  `customerID` int(11) NOT NULL,
  `nome` varchar(30) DEFAULT NULL,
  `VAT_number` varchar(30) DEFAULT NULL,
  `address` varchar(30) DEFAULT NULL,
  `phone_number` varchar(30) DEFAULT NULL,
  `PEC` varchar(30) DEFAULT NULL,
  `flag_phone` char(1) DEFAULT NULL,
  `flag_mail` char(1) DEFAULT NULL,
  `subscription` char(1) DEFAULT NULL,
  `time_remain` date DEFAULT NULL,
  `country` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struttura della tabella `dac_rules`
--

CREATE TABLE `dac_rules` (
  `code` int(11) NOT NULL,
  `RPI` varchar(30) DEFAULT NULL,
  `cusID` varchar(30) DEFAULT NULL,
  `roles` varchar(20) DEFAULT NULL,
  `wl` varchar(30) DEFAULT NULL,
  `bl` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struttura della tabella `regex`
--

CREATE TABLE `regex` (
  `ID` varchar(30) NOT NULL,
  `format` varchar(30) DEFAULT NULL,
  `flag_format` char(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struttura della tabella `user`
--

CREATE TABLE `user` (
  `userID` int(11) NOT NULL,
  `nome` varchar(30) DEFAULT NULL,
  `cognome` varchar(30) DEFAULT NULL,
  `username` varchar(30) DEFAULT NULL,
  `password` varchar(30) DEFAULT NULL,
  `fiscal_code` varchar(30) DEFAULT NULL,
  `phone_number` int(20) DEFAULT NULL,
  `mail` varchar(30) DEFAULT NULL,
  `address` varchar(50) DEFAULT NULL,
  `birth_date` varchar(20) DEFAULT NULL,
  `gender` char(1) DEFAULT NULL,
  `flag_phone` char(1) DEFAULT NULL,
  `flag_mail` char(1) DEFAULT NULL,
  `google_authenticator` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dump dei dati per la tabella `user`
--

INSERT INTO `user` (`userID`, `nome`, `cognome`, `username`, `password`, `fiscal_code`, `phone_number`, `mail`, `address`, `birth_date`, `gender`, `flag_phone`, `flag_mail`, `google_authenticator`) VALUES
(1, 'Federico', 'Villata', 'Ilvillo', 'rocchino16cm', 'vllfrc98s21', 2147483647, 'federicovillata@gmail.com', 'via rossi 2, Torino', '21/11/1998', 'M', '0', '0', '0'),
(2, NULL, NULL, 'Luca', 'password', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(3, 'Francesco', 'Bianco', 'Fra', 'password', 'Frnc99x72', 11111111, 'francesco@gmail.com', 'via torino 5, Chivasso', '5/5/1872', 'M', '0', '0', '0'),
(4, 'Roberta', 'Troia', 'robi', 'chimica', 'rbttr98dqq', 22109832, 'robertatroia@yahoo.it', 'via ciao 11, torino', '21/11/1998', 'F', '0', '0', '0'),
(5, 'Federico', 'bianchi', 'Fede', 'Password', 'asddsdsdasd', 124325365, 'federicovillata1998@gmail.com', 'via rossi 5, chieri', '21/11/1998', 'M', '0', '0', '0'),
(6, 'carlo', 'cracco', 'carlo', 'oassword', '1', 1, '1', '1', '1', '1', '1', '1', '1');

-- --------------------------------------------------------

--
-- Struttura della tabella `user_to_customer`
--

CREATE TABLE `user_to_customer` (
  `code` int(11) NOT NULL,
  `cusID` varchar(30) DEFAULT NULL,
  `userID` varchar(30) DEFAULT NULL,
  `role` varchar(20) DEFAULT NULL,
  `time_in` varchar(20) DEFAULT NULL,
  `time_out` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `access_administration`
--
ALTER TABLE `access_administration`
  ADD PRIMARY KEY (`code`);

--
-- Indici per le tabelle `access_table`
--
ALTER TABLE `access_table`
  ADD PRIMARY KEY (`code`);

--
-- Indici per le tabelle `customer`
--
ALTER TABLE `customer`
  ADD PRIMARY KEY (`customerID`);

--
-- Indici per le tabelle `dac_rules`
--
ALTER TABLE `dac_rules`
  ADD PRIMARY KEY (`code`);

--
-- Indici per le tabelle `regex`
--
ALTER TABLE `regex`
  ADD PRIMARY KEY (`ID`);

--
-- Indici per le tabelle `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`userID`);

--
-- Indici per le tabelle `user_to_customer`
--
ALTER TABLE `user_to_customer`
  ADD PRIMARY KEY (`code`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `access_administration`
--
ALTER TABLE `access_administration`
  MODIFY `code` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `access_table`
--
ALTER TABLE `access_table`
  MODIFY `code` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `customer`
--
ALTER TABLE `customer`
  MODIFY `customerID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `dac_rules`
--
ALTER TABLE `dac_rules`
  MODIFY `code` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `user`
--
ALTER TABLE `user`
  MODIFY `userID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT per la tabella `user_to_customer`
--
ALTER TABLE `user_to_customer`
  MODIFY `code` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
