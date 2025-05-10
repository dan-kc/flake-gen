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
    // let executable_path = std::env::current_exe()?; // Returns a Result<PathBuf, std::io::Error>
    // file_namematch cli.lang {
    //     None => {}
    //     Some(lang) => {}
    // }

    return Ok(());

    // Create readers and writers

    // Write to path
}
