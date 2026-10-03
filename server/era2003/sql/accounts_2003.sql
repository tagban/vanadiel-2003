-- era2003: new accounts own Rise of Zilart only (bit 1), not every expansion (4094).
-- The expansion bits are what character select and the client are told an account owns.
ALTER TABLE `accounts` ALTER COLUMN `expansions` SET DEFAULT 2;
