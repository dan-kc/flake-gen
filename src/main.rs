use camino::Utf8PathBuf;
use clap::{Parser, ValueEnum};
use strum::EnumIter;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short, long)]
    lang: Option<Language>,
    path: Utf8PathBuf,
}

#[derive(ValueEnum, Clone, Debug, EnumIter)]
enum Language {
    Rust,
    Go,
    Typescript
}
impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Rust => write!(f, "rust"),
            Language::Go => write!(f, "go"),
            Language::Typescript => write!(f, "typescript"),
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
    std::fs::copy(source_envrc_path, dest_envrc_path)?;

    println!("Succesfully created flake.nix and .envrc");

    return Ok(());
}

#[cfg(test)]
mod tests {
    use super::Language;
    use assert_cmd::Command;
    use strum::IntoEnumIterator;

    #[test]
    fn test_correct_langs_and_valid_path() -> Result<(), Box<dyn std::error::Error>> {
        for lang in Language::iter() {
            let lang_str = lang.to_string();
            let temp_dir = tempdir::TempDir::new(
                ("test_correct_langs_and_valid_path ".to_string() + &lang_str).as_str(),
            )?;
            let mut cmd = Command::cargo_bin("flake-gen")?;
            cmd.args([
                "--lang",
                lang_str.as_str(),
                temp_dir.path().to_str().unwrap(),
            ]);
            cmd.assert().success().stdout(predicates::str::contains(
                "Succesfully created flake.nix and .envrc",
            ));
        }

        // Test no language
        let temp_dir = tempdir::TempDir::new("test_correct_langs_and_valid_path")?;
        let mut cmd = Command::cargo_bin("flake-gen")?;
        cmd.args([temp_dir.path().to_str().unwrap()]);
        cmd.assert().success().stdout(predicates::str::contains(
            "Succesfully created flake.nix and .envrc",
        ));

        return Ok(());
    }

    #[test]
    fn test_invalid_lang() -> Result<(), Box<dyn std::error::Error>> {
        let temp_dir = tempdir::TempDir::new("test_invalid_lang")?;
        let mut cmd = Command::cargo_bin("flake-gen")?;
        cmd.args(["--lang", "rus", temp_dir.path().to_str().unwrap()]);
        cmd.assert().stderr(predicates::str::contains(
            "invalid value 'rus' for '--lang <LANG>'",
        ));

        Ok(())
    }

    #[test]
    fn test_invalid_flag() -> Result<(), Box<dyn std::error::Error>> {
        let temp_dir = tempdir::TempDir::new("invalid_flag")?;
        let mut cmd = Command::cargo_bin("flake-gen")?;
        cmd.args(["--lan", "rust", temp_dir.path().to_str().unwrap()]);
        cmd.assert().stderr(predicates::str::contains(
            "unexpected argument '--lan' found",
        ));

        Ok(())
    }

    #[test]
    fn test_no_path() -> Result<(), Box<dyn std::error::Error>> {
        let mut cmd = Command::cargo_bin("flake-gen")?;
        cmd.args(["--lang", "rust"]);
        cmd.assert().stderr(predicates::str::contains(
            "error: the following required arguments were not provided",
        ));

        Ok(())
    }
}
