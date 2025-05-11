use camino::Utf8PathBuf;
use clap::{Parser, ValueEnum};

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
impl From<std::io::Error> for Error {
    fn from(io_err: std::io::Error) -> Error {
        Error::Io(io_err)
    }
}

fn get_dest_file_paths(base_path: Utf8PathBuf) -> (Utf8PathBuf, Utf8PathBuf) {
    // 'dev --lang rust .'
    let (mut flake_path, mut envrc_path) = (base_path.clone(), base_path.clone());
    flake_path.push("flake.nix");
    envrc_path.push(".envrc");

    return (flake_path, envrc_path);
}
fn get_source_file_paths(lang_optional: Option<Language>) -> (Utf8PathBuf, Utf8PathBuf) {
    let flake_filename = match lang_optional {
        None => "default.nix".to_string(),
        Some(lang) => {
            let mut file_name = lang.to_string();
            file_name.push_str(".nix");
            file_name
        }
    };

    let templates_dir_path = Utf8PathBuf::from(
        std::env::var("TEMPLATES_DIR").expect("TEMPLATES_DIR environment variable not set."),
    );

    let mut flake_filepath = templates_dir_path.clone();
    flake_filepath.push(flake_filename);

    let mut envrc_filepath = templates_dir_path;
    envrc_filepath.push("envrc");

    (flake_filepath, envrc_filepath)
}

fn check_dest_files_already_exist(
    dest_flake_path: &Utf8PathBuf,
    dest_envrc_path: &Utf8PathBuf,
) -> Result<(), Error> {
    if dest_flake_path.exists() {
        return Err(Error::NixFileAlreadyExists);
    }
    if dest_envrc_path.exists() {
        return Err(Error::EnvrcFileAlreadyExists);
    }
    Ok(())
}

fn main() -> Result<(), Error> {
    let cli = Cli::parse();

    let (source_flake_path, source_envrc_path) = get_source_file_paths(cli.lang);
    let (dest_flake_path, dest_envrc_path) = get_dest_file_paths(cli.path.clone());
    check_dest_files_already_exist(&dest_flake_path, &dest_envrc_path)?;

    // NOTE: If this returns an error then some of the created folders may still remain.
    // TODO: Delete created folders in this case
    std::fs::create_dir_all(cli.path)?;

    std::fs::copy(source_flake_path, dest_flake_path)?;
    dbg!(source_envrc_path.clone());
    dbg!(dest_envrc_path.clone());
    std::fs::copy(source_envrc_path, dest_envrc_path)?;

    return Ok(());
}
