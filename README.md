# doctrine-query-count-logger
Query Count Logger for Doctrine

[![Latest Stable Version](https://poser.pugx.org/demyan112rv/doctrine-query-count-logger/v/stable)](https://packagist.org/packages/demyan112rv/mountebank-api-php)
[![Total Downloads](https://poser.pugx.org/demyan112rv/doctrine-query-count-logger/downloads)](https://packagist.org/packages/demyan112rv/mountebank-api-php)
[![License](https://poser.pugx.org/demyan112rv/doctrine-query-count-logger/license)](https://packagist.org/packages/demyan112rv/mountebank-api-php)

This Doctrine SQL Logger allows you to get the number of queries to the database at any time.

## Install

    composer require demyan112rv/doctrine-query-count-logger

## Symfony integration example

### 1. Create CompilerPass for logger
```php
namespace App\DependencyInjection\Compiler;

use Demyan112rv\DoctrineQueryCountLogger\QueryCountLogger;
use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;

class DoctrineLoggerCompilerPass implements CompilerPassInterface
{
    public function process(ContainerBuilder $container): void
    {
        $isProd = $container->getParameter('kernel.environment') === 'prod';
        $logger = $container->findDefinition(QueryCountLogger::class);
        if ($isProd) {
            $definition = $container->findDefinition('doctrine.dbal.connection.configuration');
            $definition->addMethodCall('setSQLLogger', [$logger]);
        } else {
            $definition = $container->findDefinition('doctrine.dbal.logger.chain');
            $definition->addMethodCall('addLogger', [$logger]);
        }
    }
}


```

### 2. Add CompilerPass to container
```php 
namespace App;

use App\DependencyInjection\Compiler\DoctrineLoggerCompilerPass;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    ...

    protected function buildContainer(): ContainerBuilder
    {
        $containerBuilder = parent::buildContainer();
        $containerBuilder->addCompilerPass(new DoctrineLoggerCompilerPass());

        return $containerBuilder;
    }
}
```

### 3. Create event listener
```php 
namespace App\EventListener;

use Demyan112rv\DoctrineQueryCountLogger\QueryCountLogger;
use Psr\Log\LoggerAwareTrait;
use Psr\Log\LoggerInterface;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Event\TerminateEvent;

class DoctrineQueryListener
{
    use LoggerAwareTrait;

    private const MAX_DOCTRINE_QUERY_COUNT = 100;

    /**
     * @var QueryCountLogger
     */
    private $queryCountLogger;

    public function __construct(
        QueryCountLogger $queryCountLogger,
        LoggerInterface $logger
    ) {
        $this->queryCountLogger = $queryCountLogger;
        $this->logger = $logger;
    }

    public function onKernelTerminate(TerminateEvent $event): void
    {
        if ($this->queryCountLogger->getCount() > self::MAX_DOCTRINE_QUERY_COUNT) {
            $this->logger->alert('Doctrine: a lot of queries to the database', [
                'controller' => $event->getRequest();->get('_controller'),
                'route' => $event->getRequest();->get('_route'),
                'count' => $this->queryCountLogger->getCount(),
            ]);
        }
    }
}

```

### 4. Add event listener to services.yaml
```yaml
services:
    App\EventListener\DoctrineQueryListener:
        tags:
            - { name: kernel.event_listener, event: kernel.terminate, priority: -2}
```