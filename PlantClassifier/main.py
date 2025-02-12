from CNNModel import CreateModel
from ImageProcesser import ImageDataset


def main():
    
    print('Prepering datasets....')
    dataset = ImageDataset()
    print('Training data has:')
    trainingData = dataset.create_training_data()
    print('Validation data has:')
    valData = dataset.create_validation_data()
    print('Test data has:')
    trainData = dataset.create_test_data()  
    
    print('Building neural networks...\n')
    CnnClassifier = CreateModel(train_generator=trainingData)
    
    
    print('Training plant_classifier...\n')
    CnnClassifier.train(train_generator=trainingData, validation_generator=valData)
    
    # # Pick an image from the test dataset
    # sample_image = "/research/PlantDataset/PlantCLEF2024/test/1355869/1ae6feaf1074c01a94b06b0bbea332ea59a2f39b.jpg"
    
    # # Test the trained model on a single image
    # predicted_species = CnnClassifier.predict(sample_image)
    # print(f"The model predicts: {predicted_species}")
    
    test_loss, test_acc = CnnClassifier.model.evaluate(trainData)
    print(f"Test Accuracy: {test_acc:.2f}")
    
    choose = input("Save the model? (yes/no): ").strip().lower()

    if choose in ["yes", "y"]:
        CnnClassifier.save()
        print("Model saved successfully!")
    else:
        print("Model not saved.")
        
    
    
    
    
if __name__ == "__main__":
    main()