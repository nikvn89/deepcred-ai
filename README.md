# Hướng Dẫn DevOps - DeepCred AI

Dưới đây là chuỗi lệnh CLI để khởi tạo Git, push lên GitHub và deploy tĩnh lên Vercel.

## 1. Khởi tạo Git và bỏ qua các thư mục cache
Tạo file `.gitignore` để tránh đưa các thư mục cấu hình nhạy cảm/cache lên git:

```bash
cd C:\Users\ADMIN\.gemini\antigravity\scratch\deepcred-ai
git init

# Tạo file .gitignore
echo "cache/" > .gitignore
echo "out/" >> .gitignore
echo "broadcast/" >> .gitignore
echo ".env" >> .gitignore
echo "node_modules/" >> .gitignore

git add .
git commit -m "feat: Initial commit for DeepCred AI dApp"
```

## 2. Push lên GitHub (Dùng GitHub CLI)
Giả định bạn đã cài đặt và login `gh`:

```bash
# Tạo repository public trên Github
gh repo create deepcred-ai --public --source=. --remote=origin

# Push toàn bộ code lên branch main
git branch -M main
git push -u origin main
```

## 3. Deploy Frontend Lên Vercel
Bạn đã cài Vercel CLI. Chạy lệnh sau để deploy riêng thư mục `frontend/` lên production.

```bash
# Chuyển vào thư mục frontend và deploy
cd frontend
vercel --prod --yes

# Gắn domain custom (ví dụ: deepcred-ai-app.vercel.app)
vercel alias set deepcred-ai-app.vercel.app
```
