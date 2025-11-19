import { createServer } from 'node:http';
import Database from 'better-sqlite3';
import worker from './worker.js';

// 1. 初始化数据库
const dbPath = process.env.DB_PATH || '/app/data/bot.sqlite';
const sqlite = new Database(dbPath);

// 2. 模拟 D1 数据库 API
const D1Adapter = {
    prepare: (sql) => {
        const stmt = sqlite.prepare(sql);
        return {
            bind: (...args) => ({
                stmt, args,
                first: async () => { try { return stmt.get(...args); } catch (e) { return null; } },
                run: async () => { return { success: true, meta: stmt.run(...args) }; }
            }),
        };
    },
    batch: async (statements) => {
        const runTransaction = sqlite.transaction((stmts) => {
            for (const s of stmts) s.stmt.run(...s.args);
        });
        runTransaction(statements);
        return { success: true };
    }
};

// 3. 环境变量封装
const env = {
    TG_BOT_DB: D1Adapter,
    BOT_TOKEN: process.env.BOT_TOKEN,
    ADMIN_GROUP_ID: process.env.ADMIN_GROUP_ID,
    ADMIN_IDS: process.env.ADMIN_IDS,
    // 允许通过环境变量覆盖默认配置
    WELCOME_MSG: process.env.WELCOME_MSG,
    VERIFICATION_QUESTION: process.env.VERIFICATION_QUESTION,
    VERIFICATION_ANSWER: process.env.VERIFICATION_ANSWER,
    backup_group_id: process.env.BACKUP_GROUP_ID,
    authorized_admins: process.env.AUTHORIZED_ADMINS
};

// 4. 启动 HTTP 服务器
const PORT = process.env.PORT || 3000;
createServer(async (req, res) => {
    if (req.method === 'POST') {
        const buffers = [];
        for await (const chunk of req) buffers.push(chunk);
        const body = Buffer.concat(buffers).toString();
        
        const request = {
            method: 'POST',
            json: async () => JSON.parse(body),
            url: `http://localhost${req.url}` // 模拟 URL
        };
        
        const ctx = { waitUntil: (p) => Promise.resolve(p).catch(console.error) };

        try {
            const response = await worker.fetch(request, env, ctx);
            res.writeHead(response.status || 200);
            res.end(await response.text() || "OK");
        } catch (e) {
            console.error("Worker Error:", e);
            res.writeHead(500);
            res.end("Internal Error");
        }
    } else {
        res.writeHead(200);
        res.end("Bot is running.");
    }
}).listen(PORT, () => console.log(`Listening on port ${PORT}`));