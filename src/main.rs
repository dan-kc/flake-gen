use camino::Utf8PathBuf;
use clap::{Parser, ValueEnum};
// 'dev --lang rust .'

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short, long)]
    lang: Option<Language>,
    path: Utf8PathBuf,
}

#[derive(ValueEnum, Clone, Debug)]
enum Language {
    Rust,
    Go,
}
impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Rust => write!(f, "rust"),
            Language::Go => write!(f, "go"),
        }
    }
}

#[derive(Debug)]
#[allow(dead_code)]
enum Error {
    Io(std::io::Error),
    NixFileAlreadyExists,
    EnvrcFileAlreadyExists,
}

fn get_new_file_paths(base_path: Utf8PathBuf) -> (Utf8PathBuf, Utf8PathBuf) {
    let (mut flake_path, mut envrc_path) = (base_path.clone(), base_path.clone());
    flake_path.push("flake.nix");
    envrc_path.push(".envrc");

    return (flake_path, envrc_path);
}

fn main() -> Result<(), Error> {
    let templates_dir =
        std::env::var("TEMPLATES_DIR").expect("TEMPLATES_DIR environment variable not set.");

    let template_path = std::path::PathBuf::from(templates_dir);
    println!("Looking for template at: {:?}", template_path);

    let cli = Cli::parse();

    let (flake_path, envrc_path) = get_new_file_paths(cli.path);
    if flake_path.exists() {
        return Err(Error::NixFileAlreadyExists);
    }
    if envrc_path.exists() {
        return Err(Error::EnvrcFileAlreadyExists);
    }

    // If not then create it
    // Get the template filepaths
    match std::env::current_exe() {
        Ok(exe_path) => {
            println!("Path to the current executable: {:?}", exe_path);
            // Note: Navigating from here to find related files in the Nix store
            // is unreliable due to the structure of the Nix store.
        }
        Err(e) => {
            eprintln!("Failed to get current executable path: {}", e);
        }
    }
    // file_namematch cli.lang {
    //     None => {}
    //     Some(lang) => {}
    // }

    return Ok(());

    // Create readers and writers

    // Write to path
}
