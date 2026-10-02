from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Tuple

import yaml


def _load_config(config_path: str) -> Dict[str, Any]:
    return yaml.safe_load(Path(config_path).read_text(encoding="utf-8"))


def _build_datasets(tf: Any, config: Dict[str, Any]) -> Tuple[Any, Any]:
    train_ds = tf.keras.utils.image_dataset_from_directory(
        config["dataset_dir"],
        validation_split=config.get("validation_split", 0.15),
        subset="training",
        seed=config.get("seed", 42),
        image_size=(config.get("image_size", 224), config.get("image_size", 224)),
        batch_size=config.get("batch_size", 32),
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        config["dataset_dir"],
        validation_split=config.get("validation_split", 0.15),
        subset="validation",
        seed=config.get("seed", 42),
        image_size=(config.get("image_size", 224), config.get("image_size", 224)),
        batch_size=config.get("batch_size", 32),
    )
    autotune = tf.data.AUTOTUNE
    return train_ds.prefetch(autotune), val_ds.prefetch(autotune)


def train_waste_classifier(config_path: str) -> str:
    config = _load_config(config_path)
    try:
        import tensorflow as tf
    except ImportError as exc:
        raise RuntimeError("TensorFlow is required to train the waste classifier.") from exc

    train_ds, val_ds = _build_datasets(tf, config)
    image_size = config.get("image_size", 224)
    num_classes = len(config.get("classes", []))

    inputs = tf.keras.Input(shape=(image_size, image_size, 3))
    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.05),
            tf.keras.layers.RandomContrast(0.1),
        ]
    )
    base_model = tf.keras.applications.EfficientNetB0(
        include_top=False,
        input_tensor=augmentation(inputs),
        weights="imagenet",
    )
    base_model.trainable = False
    x = tf.keras.layers.GlobalAveragePooling2D()(base_model.output)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(config.get("learning_rate", 1e-3)),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    project_dir = Path(config.get("project_dir", "runs/classifier")) / config.get("experiment_name", "waste_classifier_b0")
    project_dir.mkdir(parents=True, exist_ok=True)
    checkpoint_path = project_dir / "best.keras"
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(filepath=str(checkpoint_path), save_best_only=True, monitor="val_accuracy"),
        tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True, monitor="val_accuracy"),
    ]
    model.fit(train_ds, validation_data=val_ds, epochs=config.get("warmup_epochs", 5), callbacks=callbacks)

    base_model.trainable = True
    for layer in base_model.layers[:-20]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(config.get("fine_tune_learning_rate", 1e-4)),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.get("fine_tune_epochs", 15),
        callbacks=callbacks,
    )

    eval_metrics = model.evaluate(val_ds, return_dict=True)
    model.save(project_dir / "final.keras")
    (project_dir / "history.json").write_text(json.dumps(history.history, indent=2), encoding="utf-8")
    (project_dir / "metrics.json").write_text(json.dumps(eval_metrics, indent=2), encoding="utf-8")
    return str(project_dir / "final.keras")
