#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QtWebEngineQuick/QtWebEngineQuick>

int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QCoreApplication::setOrganizationDomain("techcoderhub.com");
    QCoreApplication::setOrganizationName("TechCoderHub");
    QCoreApplication::setApplicationName("Raemon");
    
    QGuiApplication app(argc, argv);
    
    // Initialize QtWebEngine before creating QML engine
    QtWebEngineQuick::initialize();
    
    app.setWindowIcon(QIcon("qrc:/assets/techcoderhub_logo.jpg"));
    
    const QUrl style(QStringLiteral("qrc:/Style.qml"));
    qmlRegisterSingletonType(style, "Style", 1, 0, "Style");
    
    QQmlApplicationEngine engine;
    
    // Load the QML file - using the second code's Qt6-compatible syntax
    const QUrl url(u"qrc:/main.qml"_qs);
    
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    
    engine.load(url);
    return app.exec();
}
