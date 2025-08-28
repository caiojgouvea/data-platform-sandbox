from pyspark.sql import SparkSession

if __name__ == "__main__":
    spark = SparkSession.builder.appName("HelloSpark").getOrCreate()

    data = [("Caio", 1), ("ChatGPT", 2), ("BigData", 3)]
    df = spark.createDataFrame(data, ["nome", "valor"])

    print("### DataFrame em memória ###")
    df.show()

    spark.stop()
