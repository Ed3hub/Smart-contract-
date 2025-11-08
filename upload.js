// upload.js (CommonJS version)
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");
require("dotenv").config();

const PINATA_API_KEY = process.env.PINATA_API_KEY;
const PINATA_SECRET_KEY = process.env.PINATA_SECRET_KEY;

async function uploadToIPFS() {
    // 1. Upload Image
    const imagePath = "./image.png"; // change if needed
    const imageData = new FormData();
    imageData.append("file", fs.createReadStream(imagePath));

    const imgRes = await axios.post(
        "https://api.pinata.cloud/pinning/pinFileToIPFS",
        imageData,
        {
            maxBodyLength: Infinity,
            headers: {
                ...imageData.getHeaders(),
                pinata_api_key: PINATA_API_KEY,
                pinata_secret_api_key: PINATA_SECRET_KEY,
            },
        }
    );

    const imageCID = imgRes.data.IpfsHash;
    console.log("✅ Image uploaded:", imageCID);

    // 2. Create metadata JSON dynamically
    const metadata = {
        name: "Course Completion NFT",
        description: "Earned after completing a course on Ed3 Learn & Earn platform.",
        image: `ipfs://${imageCID}`,
        attributes: [
            { trait_type: "Platform", value: "Ed3 Learn & Earn" },
            { trait_type: "Course ID", value: 1 },
        ],
    };

    fs.writeFileSync("./metadata.json", JSON.stringify(metadata, null, 2));

    // 3. Upload metadata.json
    const metaDataForm = new FormData();
    metaDataForm.append("file", fs.createReadStream("./metadata.json"));

    const metaRes = await axios.post(
        "https://api.pinata.cloud/pinning/pinFileToIPFS",
        metaDataForm,
        {
            maxBodyLength: Infinity,
            headers: {
                ...metaDataForm.getHeaders(),
                pinata_api_key: PINATA_API_KEY,
                pinata_secret_api_key: PINATA_SECRET_KEY,
            },
        }
    );

    const metadataCID = metaRes.data.IpfsHash;
    const metadataURI = `ipfs://${metadataCID}`;

    console.log("✅ Metadata uploaded:", metadataCID);
    console.log("✅ NFT Metadata URI:", metadataURI);

    return metadataURI;
}

uploadToIPFS().catch(console.error);
