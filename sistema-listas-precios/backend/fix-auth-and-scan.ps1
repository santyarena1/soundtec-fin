# backend\fix-auth-and-scan.ps1
# Run from the "backend" folder:  .\fix-auth-and-scan.ps1
# - Rewrites auth.service.ts and auth.routes.ts with clean code (no invalid selects, proper imports).
# - Scans the whole src/ for any leftover "existe" usages.

$ErrorActionPreference = "Stop"

# Resolve backend root (where this script lives)
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ROOT

function Write-File {
  param(
    [Parameter(Mandatory=$true)][string]$RelativePath,
    [Parameter(Mandatory=$true)][string]$Content
  )
  $FullPath = Join-Path -Path $ROOT -ChildPath $RelativePath
  $Dir = Split-Path -Parent $FullPath
  if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
  $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($FullPath, $Content, $Utf8NoBom)
  Write-Host ("[written] {0}" -f $RelativePath) -ForegroundColor Green
}

# ----------------------------- auth.service.ts -----------------------------
$authService = @'
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

/**
 * Creates default admin if it does not exist.
 * ADMIN_EMAIL / ADMIN_PASSWORD or admin@example.com / admin123
 */
export async function bootstrapAdmin() {
  const email = (process.env.ADMIN_EMAIL || "admin@example.com").trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || "admin123";

  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true, email: true },
  });
  if (existing) return { created: false, email };

  const passwordHash = await bcrypt.hash(password, 10);
  await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: "admin",
      descuentoPct: 0,
      isActive: true,
      mustChangePassword: false,
      passwordUpdatedAt: new Date(),
      lastPasswordResetAt: null,
      lastPasswordResetBy: null,
    },
  });

  return { created: true, email };
}

export async function ensureAdminAndLog(logger?: { info: Function }) {
  const res = await bootstrapAdmin();
  if (logger) {
    if (res.created) logger.info(`Admin creado: ${res.email}`);
    else logger.info(`Admin existente: ${res.email}`);
  } else {
    console.log(res.created ? `Admin creado: ${res.email}` : `Admin existente: ${res.email}`);
  }
}
'@

# ----------------------------- auth.routes.ts -----------------------------
$authRoutes = @'
import express, { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const router = express.Router();

type Role = "admin" | "user";
type JwtUser = { sub: string; role: Role; email: string; descuentoPct: number; iat?: number; exp?: number };

declare global {
  namespace Express { interface Request { auth?: JwtUser } }
}

/* Helpers */
function signToken(user: { id: string; role: Role; email: string; descuentoPct: number }) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET not set");
  return jwt.sign({ sub: user.id, role: user.role, email: user.email, descuentoPct: user.descuentoPct }, secret, { expiresIn: "7d" });
}

function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const hdr = req.headers.authorization || "";
    const [, token] = hdr.split(" ");
    if (!token) return res.status(401).json({ error: "Missing token" });
    const secret = process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ error: "JWT_SECRET not set" });
    const payload = jwt.verify(token, secret) as JwtUser;
    req.auth = payload;
    next();
  } catch {
    return res.status(401).json({ error: "Invalid token" });
  }
}

/* Routes */

/** POST /auth/login { email, password } */
router.post("/login", async (req, res) => {
  try {
    const { email, password } = (req.body || {}) as { email?: string; password?: string };
    if (!email || !password) return res.status(400).json({ error: "email y password requeridos" });

    // No select here (avoids any phantom field)
    const user = await prisma.user.findFirst({ where: { email: email.trim().toLowerCase() } });
    if (!user) return res.status(401).json({ error: "Credenciales inválidas" });
    if (!user.isActive) return res.status(403).json({ error: "Usuario inactivo" });

    const ok = await bcrypt.compare(password as string, (user as any).passwordHash);
    if (!ok) return res.status(401).json({ error: "Credenciales inválidas" });

    const token = signToken({ id: user.id, role: user.role as Role, email: user.email, descuentoPct: Number(user.descuentoPct || 0) });
    const { passwordHash, ...safe } = (user as any);
    return res.json({ token, user: safe });
  } catch (err) {
    console.error("POST /auth/login error", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/** GET /auth/me (needs token) */
router.get("/me", requireAuth, async (req, res) => {
  try {
    const id = req.auth!.sub;
    const user = await prisma.user.findUnique({ where: { id } }); // no select
    if (!user) return res.status(404).json({ error: "Usuario no encontrado" });
    const { passwordHash, ...safe } = (user as any);
    return res.json({ user: safe });
  } catch (err) {
    console.error("GET /auth/me error", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/** POST /auth/change-password { currentPassword, newPassword } */
router.post("/change-password", requireAuth, async (req, res) => {
  try {
    const { currentPassword, newPassword } = (req.body || {}) as { currentPassword?: string; newPassword?: string };
    if (!currentPassword || !newPassword) return res.status(400).json({ error: "currentPassword y newPassword requeridos" });
    if (newPassword.length < 6) return res.status(400).json({ error: "La nueva contraseña debe tener al menos 6 caracteres" });

    const id = req.auth!.sub;
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) return res.status(404).json({ error: "Usuario no encontrado" });

    const ok = await bcrypt.compare(currentPassword, (user as any).passwordHash);
    if (!ok) return res.status(401).json({ error: "Contraseña actual incorrecta" });

    const newHash = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id },
      data: { passwordHash: newHash, mustChangePassword: false, passwordUpdatedAt: new Date() },
      select: { id: true },
    });

    return res.json({ ok: true, message: "Contraseña actualizada" });
  } catch (err) {
    console.error("POST /auth/change-password error", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

export default router;
'@

# Write files
Write-File -RelativePath "src\modules\auth\auth.service.ts" -Content $authService
Write-File -RelativePath "src\modules\auth\auth.routes.ts"  -Content $authRoutes

# ----------------------------- scan for "existe" -----------------------------
Write-Host "`n--- scanning 'src' for the word 'existe' ---" -ForegroundColor Yellow
$hits = Get-ChildItem -Path (Join-Path $ROOT "src") -Recurse -Include *.ts,*.tsx |
  Select-String -Pattern "\bexiste\b" -AllMatches -CaseSensitive:$false |
  ForEach-Object {
    [PSCustomObject]@{ File = $_.Path.Replace("$ROOT\",""); Line = $_.LineNumber; Text = $_.Line.Trim() }
  }

if ($hits -and $hits.Count -gt 0) {
  Write-Host "Found possible usages of 'existe' (check and remove from any select/where):" -ForegroundColor Red
  $hits | ForEach-Object { Write-Host (" - {0}:{1} -> {2}" -f $_.File, $_.Line, $_.Text) -ForegroundColor Red }
} else {
  Write-Host "No occurrences of 'existe' found in src." -ForegroundColor Green
}

Write-Host "`nNEXT:" -ForegroundColor Yellow
Write-Host " 1) Close all terminals running 'npm run dev'." -ForegroundColor Gray
Write-Host " 2) taskkill /F /IM node.exe  (ignore error if none)." -ForegroundColor Gray
Write-Host " 3) Start backend again: npm run dev" -ForegroundColor Gray
Write-Host " 4) Test POST http://localhost:3000/auth/login and GET /auth/me" -ForegroundColor Gray
