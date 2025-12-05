import * as core from '@actions/core';
import * as exec from '@actions/exec';
import { DefaultArtifactClient } from '@actions/artifact';
import * as fs from 'fs';
import * as path from 'path';
import * as toml from '@iarna/toml';

interface BuildConfig {
  buildDefaults: boolean;
  binaries: string[];
  profile: string;
}

interface BinaryInfo {
  name: string;
  path: string;
  size: number;
}

interface CargoToml {
  workspace?: {
    'default-members'?: string[];
  };
}

async function run(): Promise<void> {
  try {
    // Parse inputs
    const config = parseInputs();
    
    // Read default-members from Cargo.toml if building defaults
    let defaultBinaries: string[] = [];
    if (config.buildDefaults) {
      defaultBinaries = await readDefaultMembersFromCargoToml();
      core.info(`📋 Found ${defaultBinaries.length} default-members in Cargo.toml`);
    }
    
    core.info('🔨 Build Configuration:');
    core.info(`  Profile: ${config.profile}`);
    core.info(`  Build defaults: ${config.buildDefaults}`);
    if (config.buildDefaults) {
      core.info(`  Default binaries: ${defaultBinaries.length} binaries`);
    }
    core.info(`  Additional binaries: ${config.binaries.join(', ') || 'none'}`);
    core.info('');

    // Build binaries (assumes Nix is already installed by workflow)
    await buildBinaries(config);

    // Determine output directory
    const targetFolder = getTargetFolder(config.profile);
    core.info(`📁 Target folder: ${targetFolder}`);

    // Verify built binaries
    const builtBinaries = await verifyBinaries(config, targetFolder, defaultBinaries);

    // Upload artifacts
    const shortSha = process.env.GITHUB_SHA?.substring(0, 7) || 'unknown';
    const artifactName = `all-binaries-${shortSha}`;
    await uploadArtifacts(builtBinaries, artifactName);

    // Set outputs
    core.setOutput('artifact_name', artifactName);
    core.setOutput('binaries_built', JSON.stringify(builtBinaries.map(b => b.name)));

    core.info('✅ Build completed successfully!');
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(error.message);
    } else {
      core.setFailed('An unknown error occurred');
    }
  }
}

async function readDefaultMembersFromCargoToml(): Promise<string[]> {
  const cargoTomlPath = path.join(process.cwd(), 'Cargo.toml');
  
  if (!fs.existsSync(cargoTomlPath)) {
    throw new Error(`Cargo.toml not found at ${cargoTomlPath}`);
  }

  const cargoTomlContent = fs.readFileSync(cargoTomlPath, 'utf-8');
  const parsed = toml.parse(cargoTomlContent) as CargoToml;

  if (!parsed.workspace || !parsed.workspace['default-members']) {
    throw new Error('No default-members found in Cargo.toml workspace section');
  }

  const defaultMembers = parsed.workspace['default-members'];
  
  // Extract binary names from paths
  // e.g., "aptos-node" from "aptos-node"
  // e.g., "aptos" from "crates/aptos"
  // e.g., "aptos-backup-cli" from "storage/backup/backup-cli"
  const binaryNames = defaultMembers.map(member => {
    const parts = member.split('/');
    return parts[parts.length - 1];
  });

  core.info(`📦 Default-members from Cargo.toml:`);
  binaryNames.forEach(name => core.info(`   - ${name}`));
  core.info('');

  return binaryNames;
}

function parseInputs(): BuildConfig {
  const buildDefaults = core.getInput('defaults') === 'true';
  const binariesInput = core.getInput('binaries');
  
  let binaries: string[] = [];
  if (binariesInput) {
    try {
      const parsed = JSON.parse(binariesInput);
      if (Array.isArray(parsed)) {
        binaries = parsed.map(b => String(b).trim()).filter(b => b.length > 0);
      } else {
        binaries = [String(parsed).trim()].filter(b => b.length > 0);
      }
    } catch {
      binaries = binariesInput
        .split(/[,\n]/)
        .map((b: string) => b.trim())
        .filter((b: string) => b.length > 0);
    }
  }
  
  const profile = core.getInput('profile', { required: true });

  return {
    buildDefaults,
    binaries,
    profile,
  };
}

async function buildBinaries(config: BuildConfig): Promise<void> {
  const profileArg = config.profile === 'release' ? '--release' : `--profile ${config.profile}`;

  if (config.buildDefaults) {
    core.info('📦 Building all default-member binaries...');
    await exec.exec('nix', [
      '--extra-experimental-features',
      'nix-command flakes',
      'develop',
      '-c',
      'cargo',
      'build',
      ...profileArg.split(' '),
    ]);
    core.info('✅ Default-members build complete');
    core.info('');
  }

  if (config.binaries.length > 0) {
    core.info('📦 Building additional binaries...');
    for (const binary of config.binaries) {
      core.info(`  Building: ${binary}`);
      await exec.exec('nix', [
        '--extra-experimental-features',
        'nix-command flakes',
        'develop',
        '-c',
        'cargo',
        'build',
        ...profileArg.split(' '),
        '-p',
        binary,
      ]);
    }
    core.info('✅ Additional binaries build complete');
  }
}

function getTargetFolder(profile: string): string {
  if (profile === 'release') {
    return 'target/release';
  } else if (profile === 'dev') {
    return 'target/debug';
  } else {
    return `target/${profile}`;
  }
}

async function verifyBinaries(
  config: BuildConfig,
  targetFolder: string,
  defaultBinaries: string[]
): Promise<BinaryInfo[]> {
  core.info('📋 Verifying built binaries:');
  core.info('');

  const builtBinaries: BinaryInfo[] = [];

  if (config.buildDefaults && defaultBinaries.length > 0) {
    core.info('Default-member binaries:');
    for (const binary of defaultBinaries) {
      const binaryPath = path.join(targetFolder, binary);
      if (fs.existsSync(binaryPath)) {
        const stats = fs.statSync(binaryPath);
        const sizeInMB = (stats.size / (1024 * 1024)).toFixed(2);
        core.info(`  ✅ ${binary} (${sizeInMB} MB)`);
        builtBinaries.push({ name: binary, path: binaryPath, size: stats.size });
      } else {
        throw new Error(`Binary not found: ${binary} at ${binaryPath}`);
      }
    }
    core.info('');
  }

  if (config.binaries.length > 0) {
    core.info('Additional binaries:');
    for (const binary of config.binaries) {
      const binaryPath = path.join(targetFolder, binary);
      if (fs.existsSync(binaryPath)) {
        const stats = fs.statSync(binaryPath);
        const sizeInMB = (stats.size / (1024 * 1024)).toFixed(2);
        core.info(`  ✅ ${binary} (${sizeInMB} MB)`);
        builtBinaries.push({ name: binary, path: binaryPath, size: stats.size });
      } else {
        throw new Error(`Binary not found: ${binary} at ${binaryPath}`);
      }
    }
    core.info('');
  }

  return builtBinaries;
}

async function uploadArtifacts(binaries: BinaryInfo[], artifactName: string): Promise<void> {
  core.info(`📤 Uploading ${binaries.length} binaries as artifact: ${artifactName}`);

  const artifactClient = new DefaultArtifactClient();
  const files = binaries.map(b => b.path);

  const uploadResponse = await artifactClient.uploadArtifact(
    artifactName,
    files,
    process.cwd(),
    {
      retentionDays: 7,
    }
  );

  core.info(`✅ Artifact uploaded: ${artifactName}`);
  core.info(`   ID: ${uploadResponse.id}`);
  core.info(`   Size: ${uploadResponse.size} bytes`);
}

run();