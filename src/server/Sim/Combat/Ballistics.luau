--!strict
-- Projectile math lives in Shared so clients step projectiles with exactly
-- the server's math (docs/contracts/net.md, S-1).
return require("@shared/Combat/Ballistics")
