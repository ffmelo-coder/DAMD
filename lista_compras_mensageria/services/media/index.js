const express = require("express");
const bodyParser = require("body-parser");
const {
  S3Client,
  PutObjectCommand,
  ListObjectsV2Command,
  GetObjectCommand,
} = require("@aws-sdk/client-s3");
const registry = require("../../shared/serviceRegistry");
const { v4: uuidv4 } = require("uuid");

const app = express();
app.use(bodyParser.json({ limit: "50mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "50mb" }));

const PORT = process.env.PORT || 3004;
const SERVICE_NAME = "media-service";

const s3Client = new S3Client({
  endpoint: process.env.S3_ENDPOINT || "http://localhost:4566",
  region: process.env.AWS_DEFAULT_REGION || "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || "test",
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || "test",
  },
  forcePathStyle: true,
});

const BUCKET_NAME = "shopping-images";

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.post("/media/upload", async (req, res) => {
  try {
    const { image, filename, contentType } = req.body;

    if (!image) {
      return res.status(400).json({ error: "Imagem não fornecida" });
    }

    const base64Data = image.replace(/^data:image\/\w+;base64,/, "");
    const buffer = Buffer.from(base64Data, "base64");

    let key;
    if (
      filename &&
      (filename.endsWith(".jpg") ||
        filename.endsWith(".jpeg") ||
        filename.endsWith(".png"))
    ) {
      key = `${uuidv4()}-${filename}`;
    } else {
      const extension = contentType ? contentType.split("/")[1] : "jpg";
      key = `${uuidv4()}-${filename || "image"}.${extension}`;
    }

    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: buffer,
      ContentType: contentType || "image/jpeg",
    });

    await s3Client.send(command);

    const gatewayUrl = process.env.GATEWAY_URL || "http://localhost:3000";
    const imageUrl = `${gatewayUrl}/api/media/images/${key}`;

    console.log(`Imagem salva com sucesso: ${key}`);
    res.json({
      success: true,
      key,
      url: imageUrl,
      bucket: BUCKET_NAME,
    });
  } catch (error) {
    console.error("Erro ao fazer upload:", error);
    res
      .status(500)
      .json({
        error: "Erro ao fazer upload da imagem",
        details: error.message,
      });
  }
});

app.get("/media/list", async (req, res) => {
  try {
    const command = new ListObjectsV2Command({
      Bucket: BUCKET_NAME,
    });

    const response = await s3Client.send(command);
    const images = (response.Contents || []).map((item) => ({
      key: item.Key,
      size: item.Size,
      lastModified: item.LastModified,
      url: `http://localhost:4566/${BUCKET_NAME}/${item.Key}`,
    }));

    res.json({
      success: true,
      count: images.length,
      images,
    });
  } catch (error) {
    console.error("Erro ao listar imagens:", error);
    res
      .status(500)
      .json({ error: "Erro ao listar imagens", details: error.message });
  }
});

app.get("/media/:key", async (req, res) => {
  try {
    const { key } = req.params;
    const url = `http://localhost:4566/${BUCKET_NAME}/${key}`;

    res.json({
      success: true,
      key,
      url,
      bucket: BUCKET_NAME,
    });
  } catch (error) {
    console.error("Erro ao obter imagem:", error);
    res
      .status(500)
      .json({ error: "Erro ao obter imagem", details: error.message });
  }
});

app.get("/media/image/:key", async (req, res) => {
  try {
    const { key } = req.params;
    console.log(`[media] Buscando imagem do S3: ${key}`);

    const command = new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    });

    const response = await s3Client.send(command);
    console.log(
      `[media] Imagem encontrada no S3, ContentType: ${response.ContentType}`
    );

    res.setHeader("Content-Type", response.ContentType || "image/jpeg");

    const chunks = [];
    for await (const chunk of response.Body) {
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks);
    console.log(`[media] Enviando ${buffer.length} bytes`);
    res.send(buffer);
  } catch (error) {
    console.error("[media] Erro ao buscar imagem do S3:", error.message);
    res
      .status(404)
      .json({ error: "Imagem não encontrada", details: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} rodando na porta ${PORT}`);
  registry.registerService(SERVICE_NAME, { url: `http://localhost:${PORT}` });
  console.log(
    `Conectado ao S3 LocalStack em: ${
      process.env.S3_ENDPOINT || "http://localhost:4566"
    }`
  );
});

process.on("SIGTERM", () => {
  registry.unregisterService(SERVICE_NAME, `http://localhost:${PORT}`);
  process.exit(0);
});
