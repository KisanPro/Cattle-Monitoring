@echo off
title Kisan S3 Server Cloudflare Tunnel
echo ==========================================================
echo    STARTING CLOUDFLARE TUNNEL FOR LOCAL S3 PC SERVER
echo ==========================================================
echo.
echo Pointing tunnel to http://localhost:8080...
echo.
cloudflared tunnel --url http://localhost:8080
pause
