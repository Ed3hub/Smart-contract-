import fs from 'fs';
import path from 'path';
import axios from 'axios';
import FormData from 'form-data';
import { fileURLToPath } from 'url';

// __dirname workaround for ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 🔐 Pinata API credentials (replace with your actual values)
const PINATA_API_KEY = 'bd87756e8e6be1456336';
const PINATA_API_SECRET = '6aa300332ede37b7f2be92cae506aeaff4a3964c98aa5639d5efb7088c466e49';

async function main() {
  // 1. Sample course data
  const courseData = {
    title: "Web3 Fundamentals",
    studentAddress: "0x123...abc",
    instructor: "Dr. Satoshi",
    completionDate: new Date().toISOString().split('T')[0]
  };

  // 2. Generate metadata JSON
  const metadata = {
    name: `${courseData.title} Completion Certificate`,
    description: `Awarded to ${courseData.studentAddress}`,
    image: "ipfs://Qm.../certificate.png", // Replace with actual image CID when available
    attributes: [
      { trait_type: "Course", value: courseData.title },
      { trait_type: "Student", value: courseData.studentAddress },
      { trait_type: "Completion Date", value: courseData.completionDate },
      { trait_type: "Instructor", value: courseData.instructor }
    ]
  };

  // 3. Save to file
  const metadataPath = path.join(__dirname, 'metadata.json');
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));

  // 4. Upload to Pinata
  const form = new FormData();
  form.append('file', fs.createReadStream(metadataPath));

  const res = await axios.post('https://api.pinata.cloud/pinning/pinFileToIPFS', form, {
    maxContentLength: Infinity,
    headers: {
      ...form.getHeaders(),
      pinata_api_key: PINATA_API_KEY,
      pinata_secret_api_key: PINATA_API_SECRET
    }
  });

  const cid = res.data.IpfsHash;
  console.log(`✅ Metadata uploaded to IPFS via Pinata`);
  console.log(`CID: ${cid}`);
  console.log(`Token URI: ipfs://${cid}`);
  console.log(`Gateway URL: https://gateway.pinata.cloud/ipfs/${cid}`);
}

main().catch(console.error);
