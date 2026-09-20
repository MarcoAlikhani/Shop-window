-- =====================================================================
-- FinPulse | V001__initial_schema.sql
-- Initial database design: raw -> core layers + ops + app
--
-- Conventions
--   * snake_case names, singular table names
--   * All timestamps stored in UTC
--   * Money / rates use DECIMAL, never FLOAT (no rounding errors)
--   * InnoDB engine + utf8mb4 everywhere
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Schemas (in MySQL: schema = database)
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS fin_raw  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- data exactly as received
CREATE DATABASE IF NOT EXISTS fin_core CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- clean, trusted data
CREATE DATABASE IF NOT EXISTS fin_ops  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- pipeline runs + quality checks
CREATE DATABASE IF NOT EXISTS fin_app  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- API clients, keys, usage

-- ---------------------------------------------------------------------
-- 2. fin_ops: pipeline observability
-- ---------------------------------------------------------------------
CREATE TABLE fin_ops.etl_run (
    run_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pipeline_name   VARCHAR(100)   NOT NULL,             -- e.g. 'fx_rates_daily'
    status          ENUM('running','success','failed') NOT NULL DEFAULT 'running',
    started_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    finished_at     DATETIME(3)    NULL,
    rows_extracted  INT UNSIGNED   NULL,
    rows_loaded     INT UNSIGNED   NULL,
    error_message   TEXT           NULL,
    INDEX idx_pipeline_started (pipeline_name, started_at)
) ENGINE=InnoDB;

CREATE TABLE fin_ops.data_quality_check (
    check_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id          BIGINT UNSIGNED NOT NULL,
    check_name      VARCHAR(100)   NOT NULL,             -- e.g. 'fx_rate_positive'
    table_name      VARCHAR(100)   NOT NULL,
    passed          BOOLEAN        NOT NULL,
    failed_rows     INT UNSIGNED   NOT NULL DEFAULT 0,
    checked_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_dq_run FOREIGN KEY (run_id) REFERENCES fin_ops.etl_run (run_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. fin_raw: landing zone (store the full API response, replayable)
-- ---------------------------------------------------------------------
CREATE TABLE fin_raw.api_response (
    response_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id          BIGINT UNSIGNED NULL,                -- which pipeline run fetched it
    source          VARCHAR(50)    NOT NULL,             -- e.g. 'frankfurter'
    endpoint        VARCHAR(255)   NOT NULL,
    request_params  JSON           NULL,
    http_status     SMALLINT UNSIGNED NOT NULL,
    payload         JSON           NULL,                 -- untouched response body
    fetched_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_source_fetched (source, fetched_at),
    INDEX idx_run (run_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. fin_core: clean, typed, constrained data
-- ---------------------------------------------------------------------
CREATE TABLE fin_core.currency (
    currency_code   CHAR(3)        PRIMARY KEY,          -- ISO 4217, e.g. 'EUR'
    currency_name   VARCHAR(64)    NOT NULL,
    is_active       BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;

CREATE TABLE fin_core.fx_rate (
    rate_date       DATE           NOT NULL,
    base_currency   CHAR(3)        NOT NULL,
    quote_currency  CHAR(3)        NOT NULL,
    rate            DECIMAL(20,10) NOT NULL,             -- 1 base = rate quote
    source          VARCHAR(50)    NOT NULL,
    run_id          BIGINT UNSIGNED NULL,                -- lineage: which run loaded it
    loaded_at       DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (rate_date, base_currency, quote_currency),   -- natural key -> idempotent upserts
    INDEX idx_pair_date (base_currency, quote_currency, rate_date),
    CONSTRAINT fk_fx_base  FOREIGN KEY (base_currency)  REFERENCES fin_core.currency (currency_code),
    CONSTRAINT fk_fx_quote FOREIGN KEY (quote_currency) REFERENCES fin_core.currency (currency_code),
    CONSTRAINT chk_fx_rate_positive CHECK (rate > 0)
) ENGINE=InnoDB;

CREATE TABLE fin_core.asset (
    asset_id        INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    symbol          VARCHAR(20)    NOT NULL,             -- e.g. 'AAPL', 'BTC'
    asset_type      ENUM('stock','etf','crypto') NOT NULL,
    asset_name      VARCHAR(128)   NULL,
    exchange_code   VARCHAR(20)    NOT NULL,             -- e.g. 'NASDAQ', 'GLOBAL' for crypto
    price_currency  CHAR(3)        NOT NULL,
    is_active       BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    UNIQUE KEY uq_asset (symbol, asset_type, exchange_code),
    CONSTRAINT fk_asset_ccy FOREIGN KEY (price_currency) REFERENCES fin_core.currency (currency_code)
) ENGINE=InnoDB;

CREATE TABLE fin_core.price_daily (
    asset_id        INT UNSIGNED   NOT NULL,
    price_date      DATE           NOT NULL,
    open_price      DECIMAL(20,8)  NULL,
    high_price      DECIMAL(20,8)  NULL,
    low_price       DECIMAL(20,8)  NULL,
    close_price     DECIMAL(20,8)  NOT NULL,
    volume          DECIMAL(28,8)  NULL,                 -- DECIMAL: crypto volume can be fractional
    source          VARCHAR(50)    NOT NULL,
    run_id          BIGINT UNSIGNED NULL,
    loaded_at       DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (asset_id, price_date),
    CONSTRAINT fk_price_asset FOREIGN KEY (asset_id) REFERENCES fin_core.asset (asset_id),
    CONSTRAINT chk_price_close_positive CHECK (close_price > 0),
    CONSTRAINT chk_price_high_low CHECK (high_price IS NULL OR low_price IS NULL OR high_price >= low_price)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. fin_app: who uses the API
-- ---------------------------------------------------------------------
CREATE TABLE fin_app.client (
    client_id       INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    client_name     VARCHAR(128)   NOT NULL,
    contact_email   VARCHAR(255)   NOT NULL,
    plan            ENUM('free','pro','enterprise') NOT NULL DEFAULT 'free',
    is_active       BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    UNIQUE KEY uq_client_email (contact_email)
) ENGINE=InnoDB;

CREATE TABLE fin_app.api_key (
    key_id          INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    client_id       INT UNSIGNED   NOT NULL,
    key_prefix      CHAR(8)        NOT NULL,             -- visible part, to identify a key
    key_hash        CHAR(64)       NOT NULL,             -- SHA-256 of the key; NEVER store plain keys
    created_at      DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at      DATETIME(3)    NULL,
    revoked_at      DATETIME(3)    NULL,
    UNIQUE KEY uq_key_hash (key_hash),
    CONSTRAINT fk_key_client FOREIGN KEY (client_id) REFERENCES fin_app.client (client_id)
) ENGINE=InnoDB;

CREATE TABLE fin_app.request_log (
    request_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_id          INT UNSIGNED   NULL,                 -- NULL = unauthenticated request
    endpoint        VARCHAR(255)   NOT NULL,
    status_code     SMALLINT UNSIGNED NOT NULL,
    response_ms     INT UNSIGNED   NULL,
    requested_at    DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_key_time (key_id, requested_at),
    CONSTRAINT fk_log_key FOREIGN KEY (key_id) REFERENCES fin_app.api_key (key_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Reference data (seed)
-- ---------------------------------------------------------------------
INSERT INTO fin_core.currency (currency_code, currency_name) VALUES
    ('EUR','Euro'),
    ('USD','US Dollar'),
    ('GBP','Pound Sterling'),
    ('JPY','Japanese Yen'),
    ('CHF','Swiss Franc'),
    ('CNY','Chinese Yuan Renminbi');
