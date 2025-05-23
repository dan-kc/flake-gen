use clap::{Parser, ValueEnum};
use std::{os::unix::fs::PermissionsExt, path::PathBuf};
use strum::EnumIter;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short = 'c')]
    comments: bool,
    #[arg(short = 'p')]
    package: bool,
    #[arg(short = 'd')]
    dev: bool,
    #[arg(short = 'g')]
    git: bool,
    #[arg(value_enum)]
    lang: Language,
    path: Option<PathBuf>,
}

#[derive(ValueEnum, Clone, Debug, EnumIter)]
enum Language {
    Agnostic,
}
impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::Agnostic { .. } => write!(f, "agnostic"),
        }
    }
}

#[derive(Debug)]
#[allow(dead_code)]
enum Error {
    Io(std::io::Error),
    NixFileAlreadyExists,
    EnvrcFileAlreadyExists,
    GitIgnoreAlreadyExists,
}
impl From<std::io::Error> for Error {
    fn from(io_err: std::io::Error) -> Error {
        Error::Io(io_err)
    }
}

fn main() -> Result<(), Error> {
    let cli = Cli::parse();
    let base_path = match cli.path.clone() {
        None => std::env::current_dir()?,
        Some(path) => path,
    };

    // Error if flake.nix exists
    let mut flake_path = base_path.clone();
    flake_path.push("flake.nix");
    if flake_path.exists() {
        return Err(Error::NixFileAlreadyExists);
    }

    // Error if dev flag picked and .envrc exists
    if cli.dev {
        let mut envrc_path = base_path.clone();
        envrc_path.push(".envrc");
        if envrc_path.exists() {
            return Err(Error::EnvrcFileAlreadyExists);
        }
    };

    // Error if git flag picked and .gitignore exists
    if cli.git {
        let mut gitignore_path = base_path.clone();
        gitignore_path.push(".gitignore");
        if gitignore_path.exists() {
            return Err(Error::GitIgnoreAlreadyExists);
        }
    };

    // If the disired path does not exist, then create it
    if let Some(ref path) = cli.path {
        if !path.exists() {
            std::fs::create_dir_all(path)?;
        }
    }

    // Load the templates
    let template_path = "templates/*.nix";
    let tera = match tera::Tera::new(&template_path) {
        Ok(t) => t,
        Err(e) => {
            println!("Parsing error(s): {}", e);
            ::std::process::exit(1);
        }
    };

    // Insert context
    let mut context = tera::Context::new();
    context.insert("dev", &cli.dev);
    context.insert("package", &cli.package);
    context.insert("comments", &cli.comments);

    // Get filename
    let mut flake_template_name = cli.lang.to_string();
    flake_template_name.push_str(".nix");

    // Render and save flake
    let rendered_flake = tera.render(flake_template_name.as_str(), &context).unwrap();
    std::fs::write(&flake_path, rendered_flake)?;
    let mut permissions = std::fs::metadata(&flake_path)?.permissions();
    permissions.set_mode(0o644);
    std::fs::set_permissions(flake_path, permissions)?;

    // Render and save envrc
    if cli.dev {
        let mut envrc_path = base_path.clone();
        envrc_path.push(".envrc");
        let envrc = "use flake . -Lv";
        std::fs::write(&envrc_path, envrc)?;
        let mut permissions = std::fs::metadata(&envrc_path)?.permissions();
        permissions.set_mode(0o644);
        std::fs::set_permissions(envrc_path, permissions)?;
    };

    // Render and save envrc
    if cli.git {
        let mut gitignore_path = base_path.clone();
        gitignore_path.push(".envrc");
        let gitignore = ".direnv/";
        std::fs::write(&gitignore_path, gitignore)?;
        let mut permissions = std::fs::metadata(&gitignore_path)?.permissions();
        permissions.set_mode(0o644);
        std::fs::set_permissions(gitignore_path, permissions)?;
    };

    Ok(())
}

// #[cfg(test)]
// mod tests {
//     use super::Language;
//     use assert_cmd::Command;
//     use strum::IntoEnumIterator;
//
//     #[test]
//     fn test_correct_langs_and_valid_path() {
//         for lang in Language::iter() {
//             let lang_str = lang.to_string();
//             let temp_dir = tempdir::TempDir::new(
//                 ("test_correct_langs_and_valid_path ".to_string() + &lang_str).as_str(),
//             )
//             .unwrap();
//             let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//             cmd.args([lang_str.as_str(), temp_dir.path().to_str().unwrap()]);
//             cmd.assert().success().stdout(predicates::str::contains(
//                 "Succesfully created flake.nix and .envrc",
//             ));
//         }
//     }
//
//     #[test]
//     fn test_invalid_lang() {
//         let temp_dir = tempdir::TempDir::new("test_invalid_lang").unwrap();
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rus", temp_dir.path().to_str().unwrap()]);
//         cmd.assert().stderr(predicates::str::contains(""));
//     }
//
//     #[test]
//     fn test_invalid_flag() {
//         let temp_dir = tempdir::TempDir::new("invalid_flag").unwrap();
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rust", "--u", temp_dir.path().to_str().unwrap()]);
//         cmd.assert()
//             .stderr(predicates::str::contains("unexpected argument '--u' found"));
//     }
//
//     #[test]
//     fn test_no_path() {
//         let mut cmd = Command::cargo_bin("flake-gen").unwrap();
//         cmd.args(["rust"]);
//         cmd.assert().stderr(predicates::str::contains(
//             "error: the following required arguments were not provided",
//         ));
//     }
// }
